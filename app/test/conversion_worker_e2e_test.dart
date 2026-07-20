import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/services/conversion_worker_client.dart';
import 'package:open_pdf/services/worker_locator.dart';

void main() {
  final repoRoot = _findRepoRoot();
  final samplePdf = File('$repoRoot/corpus/ruled_table.pdf');
  final expectedSpec = jsonDecode(
    File('$repoRoot/corpus/ruled_table.expected.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  late WorkerLocator locator;
  late Directory tempDir;
  late String workerExecutable;

  setUpAll(() {
    if (!samplePdf.existsSync()) {
      Process.runSync(
        Platform.isWindows ? 'python' : 'python3',
        ['$repoRoot/corpus/generate_ruled_table_pdf.py'],
        workingDirectory: repoRoot,
      );
    }

    locator = WorkerLocator(repoRoot: repoRoot);
    workerExecutable = locator.resolvedExecutablePath() ?? '';
    if (workerExecutable.isEmpty || !File(workerExecutable).existsSync()) {
      fail(
        'Distributable worker not found. Run scripts/freeze_worker.sh before '
        'conversion_worker_e2e_test.dart.',
      );
    }

    tempDir = Directory.systemTemp.createTempSync('open-pdf-e2e-');
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  test(
    'handshake succeeds against distributable worker build',
    () async {
      final client = ConversionWorkerClient(locator: locator);
      await client.start();
      try {
        final result = await client.handshake();
        expect(result.protocolVersion, '1.0');
        expect(result.workerVersion, isNotEmpty);
      } finally {
        await client.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'converts representative PDF to editable workbook',
    () async {
      final output = File('${tempDir.path}/ruled_table.xlsx');
      if (output.existsSync()) {
        output.deleteSync();
      }

      final client = ConversionWorkerClient(locator: locator);
      await client.start();
      await client.handshake();

      ConversionComplete? complete;
      final progressEvents = <ConversionProgress>[];

      await for (final event in client.convert(
        requestId: 'e2e-ruled-table',
        inputPdf: samplePdf.absolute.path,
        outputXlsx: output.absolute.path,
        pages: '1',
      )) {
        if (event is ConversionProgress) {
          progressEvents.add(event);
        } else if (event is ConversionComplete) {
          complete = event;
        }
      }
      await client.close();

      expect(complete, isNotNull);
      expect(output.existsSync(), isTrue);
      expect(complete!.worksheets.length, greaterThanOrEqualTo(1));
      expect(progressEvents, isNotEmpty);
      expect(
        progressEvents.first.percent,
        lessThan(progressEvents.last.percent),
      );

      final requiredValues = (expectedSpec['required_values'] as List<dynamic>)
          .cast<String>()
          .toSet();
      final workbookText = _readWorkbookText(output);
      for (final value in requiredValues) {
        expect(workbookText, contains(value), reason: 'Missing value $value');
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

String _readWorkbookText(File workbook) {
  final archive = ZipDecoder().decodeBytes(workbook.readAsBytesSync());
  final buffer = StringBuffer();
  for (final file in archive.files) {
    if (file.name.startsWith('xl/')) {
      buffer.writeln(String.fromCharCodes(file.content as List<int>));
    }
  }
  return buffer.toString();
}

String _findRepoRoot() {
  var dir = Directory.current;
  for (var depth = 0; depth < 8; depth++) {
    if (File('${dir.path}/tickets.md').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }

  throw StateError('Could not locate repository root from ${Directory.current.path}.');
}
