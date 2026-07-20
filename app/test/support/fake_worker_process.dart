import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// In-memory [Process] that speaks a minimal conversion-worker protocol.
class FakeWorkerProcess implements Process {
  FakeWorkerProcess({
    this.hangAfterProgress = false,
    this.emitMalformedAfterProgress = false,
    this.crashAfterProgress = false,
    this.cancelDelay = Duration.zero,
  }) {
    _stdinController.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onStdinLine);
  }

  final bool hangAfterProgress;
  final bool emitMalformedAfterProgress;
  final bool crashAfterProgress;
  final Duration cancelDelay;

  final _stdinController = StreamController<List<int>>();
  final _stdoutController = StreamController<List<int>>();
  final _stderrController = StreamController<List<int>>();
  final _exitCompleter = Completer<int>();

  var _killed = false;
  String? _activeRequestId;

  final receivedMessages = <Map<String, dynamic>>[];

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  IOSink get stdin => _FakeStdin(_stdinController);

  @override
  int get pid => 4242;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _killed = true;
    _finish(143);
    return true;
  }

  bool get wasKilled => _killed;

  void emitStderr(String line) {
    _stderrController.add(utf8.encode('$line\n'));
  }

  void _onStdinLine(String line) {
    if (line.trim().isEmpty || _exitCompleter.isCompleted) {
      return;
    }

    final message = jsonDecode(line) as Map<String, dynamic>;
    receivedMessages.add(message);

    switch (message['type']) {
      case 'handshake':
        _writeEvent({
          'type': 'handshake_ack',
          'protocol_version': '1.0',
          'worker_version': '0.1.0-fake',
        });
      case 'convert':
        _activeRequestId = message['request_id'] as String?;
        _writeEvent({
          'type': 'progress',
          'request_id': _activeRequestId,
          'stage': 'extracting',
          'percent': 20,
          'message': 'Extracting tables.',
        });
        if (emitMalformedAfterProgress) {
          _stdoutController.add(utf8.encode('not-json\n'));
          return;
        }
        if (crashAfterProgress) {
          _finish(1);
          return;
        }
        if (hangAfterProgress) {
          return;
        }
        _writeEvent({
          'type': 'complete',
          'request_id': _activeRequestId,
          'output_xlsx': message['output_xlsx'],
          'worksheets': [
            {
              'name': 'Table 1 p1',
              'source_pages': [1],
              'extraction_method': 'digital',
            },
          ],
        });
      case 'cancel':
        final requestId = message['request_id'];
        if (requestId != _activeRequestId) {
          return;
        }
        Future<void>.delayed(cancelDelay, () {
          if (_exitCompleter.isCompleted) {
            return;
          }
          _writeEvent({
            'type': 'error',
            'code': 'CANCELLED',
            'message': 'Conversion cancelled.',
            'request_id': requestId,
          });
        });
    }
  }

  void _writeEvent(Map<String, dynamic> event) {
    if (_exitCompleter.isCompleted || _stdoutController.isClosed) {
      return;
    }
    _stdoutController.add(utf8.encode('${jsonEncode(event)}\n'));
  }

  void _finish(int code) {
    if (_exitCompleter.isCompleted) {
      return;
    }
    unawaited(_stdoutController.close());
    unawaited(_stderrController.close());
    _exitCompleter.complete(code);
  }
}

class _FakeStdin implements IOSink {
  _FakeStdin(this._controller);

  final StreamController<List<int>> _controller;

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) => _controller.add(data);

  @override
  void writeln([Object? object = '']) {
    add(utf8.encode('$object\n'));
  }

  @override
  void write(Object? object) {
    add(utf8.encode('$object'));
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    add([charCode]);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _controller.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) => stream.forEach(add);

  @override
  Future flush() async {}

  @override
  Future close() async {
    await _controller.close();
  }

  @override
  Future get done => _controller.done;
}
