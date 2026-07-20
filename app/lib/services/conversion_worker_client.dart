import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:open_pdf/services/conversion_diagnostics.dart';
import 'package:open_pdf/services/conversion_protocol.dart';
import 'package:open_pdf/services/worker_locator.dart';

class ConversionProgress {
  const ConversionProgress({
    required this.stage,
    required this.percent,
    required this.message,
  });

  final String stage;
  final int percent;
  final String message;
}

class ConversionComplete {
  const ConversionComplete({
    required this.outputPath,
    required this.worksheets,
  });

  final String outputPath;
  final List<ConversionWorksheet> worksheets;
}

class ConversionWorksheet {
  const ConversionWorksheet({
    required this.name,
    required this.sourcePages,
  });

  factory ConversionWorksheet.fromJson(Map<String, dynamic> json) {
    final sourcePages = json['source_pages'];
    return ConversionWorksheet(
      name: json['name'] as String,
      sourcePages: _formatSourcePages(sourcePages),
    );
  }

  static String _formatSourcePages(Object? sourcePages) {
    if (sourcePages is List) {
      return sourcePages.map((page) => page.toString()).join(', ');
    }
    return sourcePages?.toString() ?? '';
  }

  final String name;
  final String sourcePages;
}

class ConversionFailure implements Exception, ConversionFailureLike {
  ConversionFailure({
    required this.code,
    required this.message,
    this.requestId,
  });

  factory ConversionFailure.fromJson(Map<String, dynamic> json) {
    return ConversionFailure(
      code: json['code'] as String? ?? 'CONVERSION_FAILED',
      message: json['message'] as String? ?? 'Conversion failed.',
      requestId: json['request_id'] as String?,
    );
  }

  @override
  final String code;
  @override
  final String message;
  final String? requestId;

  @override
  String toString() => '$code: $message';
}

class HandshakeResult {
  const HandshakeResult({
    required this.protocolVersion,
    required this.workerVersion,
  });

  final String protocolVersion;
  final String workerVersion;
}

/// Spawns the worker directly and exchanges newline-delimited JSON events.
class ConversionWorkerClient {
  ConversionWorkerClient({
    WorkerLocator? locator,
    ProcessStartCallback? processStarter,
  })  : _locator = locator ?? const WorkerLocator(),
        _processStarter = processStarter ?? Process.start;

  final WorkerLocator _locator;
  final ProcessStartCallback _processStarter;

  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  final _pendingLines = <String>[];
  final _diagnosticsLines = <String>[];
  Completer<void>? _waitForLine;
  var _closed = false;
  var _stdoutClosed = false;
  var _terminated = false;

  List<String> get diagnosticsLines => List.unmodifiable(_diagnosticsLines);

  Future<void> start() async {
    if (_process != null) {
      return;
    }

    final command = _locator.resolveLaunchCommand();
    _process = await _processStarter(
      command.first,
      command.skip(1).toList(),
      workingDirectory: _locator.workingDirectory(),
      mode: ProcessStartMode.normal,
    );

    final process = _process!;
    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _onLine,
          onDone: () {
            _stdoutClosed = true;
            _waitForLine?.complete();
            _waitForLine = null;
          },
        );
    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.trim().isNotEmpty) {
            _diagnosticsLines.add(line);
          }
        });
  }

  void _onLine(String line) {
    if (line.trim().isEmpty) {
      return;
    }
    _pendingLines.add(line);
    _waitForLine?.complete();
    _waitForLine = null;
  }

  Future<Map<String, dynamic>> _readEvent() async {
    while (_pendingLines.isEmpty) {
      if (_closed || _terminated || _stdoutClosed) {
        throw ConversionFailure(
          code: 'WORKER_CRASHED',
          message: 'Worker closed unexpectedly.',
        );
      }

      _waitForLine = Completer<void>();
      await _waitForLine!.future;

      if (_pendingLines.isEmpty && (_stdoutClosed || _terminated || _closed)) {
        throw ConversionFailure(
          code: 'WORKER_CRASHED',
          message: 'Worker closed before sending a response.',
        );
      }
    }

    final line = _pendingLines.removeAt(0);
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) {
        throw ConversionFailure(
          code: 'MALFORMED_EVENT',
          message: 'Worker sent a non-object event.',
        );
      }
      return decoded;
    } on ConversionFailure {
      rethrow;
    } on FormatException catch (error) {
      throw ConversionFailure(
        code: 'MALFORMED_EVENT',
        message: 'Worker sent invalid JSON: $error',
      );
    }
  }

  Future<void> send(Map<String, dynamic> message) async {
    final process = _process;
    if (process == null) {
      throw StateError('Worker not started.');
    }
    process.stdin.writeln(jsonEncode(message));
    await process.stdin.flush();
  }

  Future<void> cancel(String requestId) {
    return send({
      'type': 'cancel',
      'request_id': requestId,
    });
  }

  Future<void> terminate() async {
    _terminated = true;
    final process = _process;
    if (process == null) {
      return;
    }
    process.kill();
    _waitForLine?.complete();
    _waitForLine = null;
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
  }

  Future<HandshakeResult> handshake() async {
    await send({
      'type': 'handshake',
      'protocol_version': ConversionProtocol.protocolVersion,
    });

    final event = await _readEvent();
    if (event['type'] != 'handshake_ack') {
      if (event['type'] == 'error') {
        throw ConversionFailure.fromJson(event);
      }
      throw ConversionFailure(
        code: 'PROTOCOL_MISMATCH',
        message: 'Expected handshake_ack, got ${event['type']}.',
      );
    }

    if (event['protocol_version'] != ConversionProtocol.protocolVersion) {
      throw ConversionFailure(
        code: 'PROTOCOL_MISMATCH',
        message: 'Unsupported protocol version: ${event['protocol_version']}.',
      );
    }

    return HandshakeResult(
      protocolVersion: event['protocol_version'] as String,
      workerVersion: event['worker_version'] as String,
    );
  }

  Stream<Object> convert({
    required String requestId,
    required String inputPdf,
    required String outputXlsx,
    String? pages,
  }) async* {
    final message = <String, dynamic>{
      'type': 'convert',
      'request_id': requestId,
      'input_pdf': inputPdf,
      'output_xlsx': outputXlsx,
    };
    if (pages != null && pages.trim().isNotEmpty) {
      message['pages'] = pages.trim();
    }
    await send(message);

    while (true) {
      final event = await _readEvent();
      switch (event['type']) {
        case 'progress':
          yield ConversionProgress(
            stage: event['stage'] as String,
            percent: event['percent'] as int,
            message: event['message'] as String,
          );
        case 'complete':
          final worksheets = (event['worksheets'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map(ConversionWorksheet.fromJson)
              .toList(growable: false);
          yield ConversionComplete(
            outputPath: event['output_xlsx'] as String,
            worksheets: worksheets,
          );
          return;
        case 'error':
          throw ConversionFailure.fromJson(event);
        default:
          throw ConversionFailure(
            code: 'MALFORMED_EVENT',
            message: 'Unexpected worker event: ${event['type']}',
          );
      }
    }
  }

  Future<void> close({bool force = false}) async {
    _closed = true;
    final process = _process;
    if (process != null) {
      if (force || _terminated) {
        process.kill();
      } else {
        try {
          await process.stdin.close();
        } on StateError {
          // stdin already closed after terminate
        }
      }
      try {
        await process.exitCode.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      } on ProcessException {
        // process already gone
      }
    }
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _process = null;
    _waitForLine?.complete();
    _waitForLine = null;
  }
}

typedef ProcessStartCallback = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  ProcessStartMode mode,
});
