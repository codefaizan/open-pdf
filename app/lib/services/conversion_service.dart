import 'dart:io';

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
  })  : _saveService = saveService ?? const NativeExcelSaveService(),
        _workerLocator = workerLocator ?? const WorkerLocator(),
        _clientFactory = clientFactory ??
            ((locator) => ConversionWorkerClient(locator: locator));

  final ExcelSaveService _saveService;
  final WorkerLocator _workerLocator;
  final ConversionWorkerClient Function(WorkerLocator locator) _clientFactory;

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
    return '$destinationPath.converting-$timestamp.xlsx';
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
    return destinationPath;
  }

  Stream<Object> runConversion(ConversionRequest request) async* {
    if (!isValidPageRange(request.pages)) {
      throw ConversionFailure(
        code: 'INVALID_REQUEST',
        message: 'Invalid page range: ${request.pages}.',
      );
    }

    final client = _clientFactory(_workerLocator);
    await client.start();
    try {
      await client.handshake();
      yield* client.convert(
        requestId: 'convert-${DateTime.now().microsecondsSinceEpoch}',
        inputPdf: File(request.inputPdf).absolute.path,
        outputXlsx: File(request.outputXlsx).absolute.path,
        pages: request.pages,
      );
    } finally {
      await client.close();
    }
  }
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
