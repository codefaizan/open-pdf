import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/services/conversion_service.dart';
import 'package:open_pdf/services/conversion_worker_client.dart';
import 'package:open_pdf/services/excel_save_service.dart';
import 'package:open_pdf/services/worker_locator.dart';
import 'package:path/path.dart' as p;

import 'support/fake_worker_process.dart';

class _MemorySaveService implements ExcelSaveService {
  @override
  Future<String?> pickSaveLocation({required String suggestedName}) async =>
      suggestedName;

  @override
  bool destinationExists(String path) => File(path).existsSync();
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('open-pdf-service-');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ConversionService buildService({
    required FakeWorkerProcess Function() processFactory,
    Duration timeout = const Duration(seconds: 30),
    Duration cancelGracePeriod = const Duration(milliseconds: 50),
  }) {
    return ConversionService(
      saveService: _MemorySaveService(),
      workerLocator: const WorkerLocator(environment: '/fake/worker'),
      timeout: timeout,
      cancelGracePeriod: cancelGracePeriod,
      clientFactory: (locator) => ConversionWorkerClient(
        locator: locator,
        processStarter: (
          executable,
          arguments, {
          String? workingDirectory,
          ProcessStartMode mode = ProcessStartMode.normal,
        }) async =>
            processFactory(),
      ),
    );
  }

  test('cancelActiveConversion stops an in-flight conversion', () async {
    late FakeWorkerProcess fake;
    final service = buildService(
      processFactory: () {
        fake = FakeWorkerProcess(hangAfterProgress: true);
        return fake;
      },
    );

    final input = File(p.join(tempDir.path, 'in.pdf'))..writeAsStringSync('%PDF');
    final output = File(p.join(tempDir.path, 'out.xlsx'));

    ConversionFailure? failure;
    final events = <Object>[];

    final done = () async {
      try {
        await for (final event in service.runConversion(
          ConversionRequest(
            inputPdf: input.path,
            outputXlsx: output.path,
          ),
        )) {
          events.add(event);
          if (event is ConversionProgress) {
            await service.cancelActiveConversion();
          }
        }
      } on ConversionFailure catch (error) {
        failure = error;
      }
    }();

    await done;

    expect(events.whereType<ConversionProgress>(), isNotEmpty);
    expect(failure?.code, 'CANCELLED');
    expect(output.existsSync(), isFalse);
    expect(
      fake.receivedMessages.any((message) => message['type'] == 'cancel'),
      isTrue,
    );
  });

  test('timeout cancels then kills a hung conversion', () async {
    late FakeWorkerProcess fake;
    final service = buildService(
      timeout: const Duration(milliseconds: 80),
      cancelGracePeriod: const Duration(milliseconds: 40),
      processFactory: () {
        fake = FakeWorkerProcess(hangAfterProgress: true);
        return fake;
      },
    );

    final input = File(p.join(tempDir.path, 'in.pdf'))..writeAsStringSync('%PDF');
    final output = File(p.join(tempDir.path, 'out.xlsx'));

    await expectLater(
      service
          .runConversion(
            ConversionRequest(
              inputPdf: input.path,
              outputXlsx: output.path,
            ),
          )
          .drain<void>(),
      throwsA(
        isA<ConversionFailure>().having((error) => error.code, 'code', 'TIMEOUT'),
      ),
    );

    expect(fake.wasKilled, isTrue);
    expect(output.existsSync(), isFalse);
  });

  test('failed conversion deletes tracked temporary output paths', () async {
    final service = buildService(
      processFactory: () => FakeWorkerProcess(crashAfterProgress: true),
    );

    final input = File(p.join(tempDir.path, 'in.pdf'))..writeAsStringSync('%PDF');
    final tempOutput = File(
      service.temporaryReplacementPath(p.join(tempDir.path, 'dest.xlsx')),
    );
    tempOutput.writeAsBytesSync([1, 2, 3]);
    expect(tempOutput.existsSync(), isTrue);

    try {
      await service
          .runConversion(
            ConversionRequest(
              inputPdf: input.path,
              outputXlsx: tempOutput.path,
            ),
          )
          .drain<void>();
      fail('expected conversion failure');
    } on ConversionFailure {
      // expected
    }

    expect(tempOutput.existsSync(), isFalse);
  });

  test('launch command never uses a shell string for adversarial paths', () {
    final locator = WorkerLocator(
      environment: r'/tmp/evil; rm -rf / --name "weird.pdf"',
    );
    final command = locator.resolveLaunchCommand();
    expect(command, hasLength(1));
    expect(command.first, contains('evil; rm -rf'));
    expect(command.join(' '), isNot(contains(r'sh -c')));
  });
}
