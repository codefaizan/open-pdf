import 'dart:async';
import 'dart:io';

import 'package:open_pdf/services/conversion_diagnostics.dart';
import 'package:open_pdf/services/conversion_protocol.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_pdf/services/conversion_worker_client.dart';
import 'package:open_pdf/services/excel_save_service.dart';
import 'package:open_pdf/services/worker_locator.dart';
import 'package:path/path.dart' as p;

class ConversionRequest {
  const ConversionRequest({
    required this.inputPdf,
    required this.outputXlsx,
    this.pages,
  });

  final String inputPdf;
  final String outputXlsx;
  final String? pages;
}

/// Orchestrates save-dialog selection and worker conversion.
class ConversionService {
  ConversionService({
    ExcelSaveService? saveService,
    WorkerLocator? workerLocator,
    ConversionWorkerClient Function(WorkerLocator locator)? clientFactory,
    this.timeout = const Duration(minutes: 15),
    this.cancelGracePeriod = const Duration(seconds: 2),
    this.appVersion = ConversionDiagnostics.defaultAppVersion,
  })  : _saveService = saveService ?? const NativeExcelSaveService(),
        _workerLocator = workerLocator ?? const WorkerLocator(),
        _clientFactory = clientFactory ??
            ((locator) => ConversionWorkerClient(locator: locator));

  final ExcelSaveService _saveService;
  final WorkerLocator _workerLocator;
  final ConversionWorkerClient Function(WorkerLocator locator) _clientFactory;
  final Duration timeout;
  final Duration cancelGracePeriod;
  final String appVersion;

  ConversionWorkerClient? _activeClient;
  String? _activeRequestId;
  String? _workerVersion;
  var _cancelRequested = false;
  final _trackedTemps = <String>{};

  ConversionDiagnostics diagnostics() {
    return ConversionDiagnostics(
      appVersion: appVersion,
      workerVersion: _workerVersion,
      protocolVersion: ConversionProtocol.protocolVersion,
    );
  }

  String suggestedWorkbookName(String pdfPath) {
    final base = p.basenameWithoutExtension(pdfPath);
    return '$base.xlsx';
  }

  Future<String?> pickDestination(String pdfPath) {
    return _saveService.pickSaveLocation(
      suggestedName: suggestedWorkbookName(pdfPath),
    );
  }

  bool destinationExists(String path) => _saveService.destinationExists(path);

  String temporaryReplacementPath(String destinationPath) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$destinationPath.converting-$timestamp.xlsx';
    _trackedTemps.add(path);
    return path;
  }

  Future<String> finalizeReplacement({
    required String temporaryPath,
    required String destinationPath,
  }) async {
    final temporary = File(temporaryPath);
    final destination = File(destinationPath);
    if (destination.existsSync()) {
      await destination.delete();
    }
    await temporary.rename(destinationPath);
    _trackedTemps.remove(temporaryPath);
    return destinationPath;
  }

  Future<void> cancelActiveConversion() async {
    final client = _activeClient;
    final requestId = _activeRequestId;
    if (client == null || requestId == null) {
      return;
    }
    _cancelRequested = true;
    try {
      await client.cancel(requestId);
    } catch (_) {}
    unawaited(_escalateCancel(client));
  }

  Future<void> _escalateCancel(ConversionWorkerClient client) async {
    await Future<void>.delayed(cancelGracePeriod);
    if (_activeClient == client) {
      await client.terminate();
    }
  }

  Future<void> cleanupLeftoverTemps() => _cleanupTrackedTemps();

  Stream<Object> runConversion(ConversionRequest request) async* {
    if (!isValidPageRange(request.pages)) {
      throw ConversionFailure(
        code: 'INVALID_REQUEST',
        message: 'Invalid page range: ${request.pages}.',
      );
    }

    final client = _clientFactory(_workerLocator);
    final requestId = 'convert-${DateTime.now().microsecondsSinceEpoch}';
    final outputPath = File(request.outputXlsx).absolute.path;
    _trackedTemps.add(outputPath);

    await client.start();
    _activeClient = client;
    _activeRequestId = requestId;

    var succeeded = false;
    try {
      final handshake = await client.handshake();
      _workerVersion = handshake.workerVersion;

      await for (final event in _convertWithTimeout(
        client: client,
        requestId: requestId,
        inputPdf: File(request.inputPdf).absolute.path,
        outputXlsx: outputPath,
        pages: request.pages,
      )) {
        yield event;
      }
      succeeded = true;
      // Replacement temps stay tracked until finalizeReplacement.
      if (!_isReplacementTemp(outputPath)) {
        _trackedTemps.remove(outputPath);
      }
    } on ConversionFailure catch (error) {
      if (_cancelRequested &&
          (error.code == 'WORKER_CRASHED' || error.code == 'TIMEOUT')) {
        throw ConversionFailure(
          code: 'CANCELLED',
          message: 'Conversion cancelled.',
          requestId: error.requestId,
        );
      }
      rethrow;
    } catch (error) {
      throw ConversionFailure(
        code: 'CONVERSION_FAILED',
        message: 'Conversion failed: $error',
      );
    } finally {
      if (!succeeded) {
        await _cleanupTrackedTemps();
      }
      _cancelRequested = false;
      _activeClient = null;
      _activeRequestId = null;
      await client.close();
    }
  }

  Stream<Object> _convertWithTimeout({
    required ConversionWorkerClient client,
    required String requestId,
    required String inputPdf,
    required String outputXlsx,
    String? pages,
  }) async* {
    final controller = StreamController<Object>();
    var timedOut = false;
    Timer? timer;

    timer = Timer(timeout, () async {
      timedOut = true;
      try {
        await client.cancel(requestId);
      } catch (_) {}
      await Future<void>.delayed(cancelGracePeriod);
      await client.terminate();
      if (!controller.isClosed) {
        controller.addError(
          ConversionFailure(
            code: 'TIMEOUT',
            message: 'Conversion timed out.',
            requestId: requestId,
          ),
        );
        await controller.close();
      }
    });

    final subscription = client
        .convert(
          requestId: requestId,
          inputPdf: inputPdf,
          outputXlsx: outputXlsx,
          pages: pages,
        )
        .listen(
          (event) {
            if (!timedOut && !controller.isClosed) {
              controller.add(event);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (timedOut || controller.isClosed) {
              return;
            }
            controller.addError(error, stackTrace);
          },
          onDone: () {
            if (!timedOut && !controller.isClosed) {
              controller.close();
            }
          },
        );

    try {
      await for (final event in controller.stream) {
        yield event;
      }
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

  Future<void> _cleanupTrackedTemps() async {
    final paths = List<String>.from(_trackedTemps);
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          await file.delete();
        } on FileSystemException {
          // best-effort cleanup
        }
      }
      _trackedTemps.remove(path);
    }
  }

  static bool _isReplacementTemp(String path) =>
      path.contains('.converting-');
}

/// Opens a saved workbook or reveals it in the file manager.
class WorkbookActions {
  const WorkbookActions();

  Future<bool> openWorkbook(String path) {
    return launchUrl(Uri.file(path));
  }

  Future<bool> revealWorkbook(String path) async {
    if (Platform.isMacOS) {
      final result = await Process.run('open', ['-R', path], runInShell: false);
      return result.exitCode == 0;
    }
    if (Platform.isWindows) {
      final result = await Process.run(
        'explorer',
        ['/select,', path],
        runInShell: false,
      );
      return result.exitCode == 0;
    }
    return openWorkbook(path);
  }
}
