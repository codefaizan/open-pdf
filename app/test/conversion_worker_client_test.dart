import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/services/conversion_worker_client.dart';
import 'package:open_pdf/services/worker_locator.dart';

import 'support/fake_worker_process.dart';

void main() {
  test('cancel stops conversion and surfaces CANCELLED without completing', () async {
    late FakeWorkerProcess fake;
    final client = ConversionWorkerClient(
      locator: const WorkerLocator(environment: '/fake/worker'),
      processStarter: (
        executable,
        arguments, {
        String? workingDirectory,
        ProcessStartMode mode = ProcessStartMode.normal,
      }) async {
        fake = FakeWorkerProcess(hangAfterProgress: true);
        return fake;
      },
    );

    await client.start();
    await client.handshake();

    ConversionFailure? failure;
    final progress = <ConversionProgress>[];

    final convertFuture = () async {
      try {
        await for (final event in client.convert(
          requestId: 'cancel-me',
          inputPdf: '/tmp/in.pdf',
          outputXlsx: '/tmp/out.xlsx',
        )) {
          if (event is ConversionProgress) {
            progress.add(event);
            await client.cancel('cancel-me');
          }
        }
      } on ConversionFailure catch (error) {
        failure = error;
      }
    }();

    await convertFuture;
    await client.close();

    expect(progress, isNotEmpty);
    expect(failure, isNotNull);
    expect(failure!.code, 'CANCELLED');
    expect(
      fake.receivedMessages.any((message) => message['type'] == 'cancel'),
      isTrue,
    );
  });

  test('terminate kills a hung worker process', () async {
    late FakeWorkerProcess fake;
    final client = ConversionWorkerClient(
      locator: const WorkerLocator(environment: '/fake/worker'),
      processStarter: (
        executable,
        arguments, {
        String? workingDirectory,
        ProcessStartMode mode = ProcessStartMode.normal,
      }) async {
        fake = FakeWorkerProcess(hangAfterProgress: true);
        return fake;
      },
    );

    await client.start();
    await client.handshake();

    final convertFuture = client.convert(
      requestId: 'hang',
      inputPdf: '/tmp/in.pdf',
      outputXlsx: '/tmp/out.xlsx',
    ).drain<void>().catchError((_) {});

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await client.terminate();
    await convertFuture;

    expect(fake.wasKilled, isTrue);
  });

  test('malformed worker event becomes MALFORMED_EVENT failure', () async {
    final client = ConversionWorkerClient(
      locator: const WorkerLocator(environment: '/fake/worker'),
      processStarter: (
        executable,
        arguments, {
        String? workingDirectory,
        ProcessStartMode mode = ProcessStartMode.normal,
      }) async {
        return FakeWorkerProcess(emitMalformedAfterProgress: true);
      },
    );

    await client.start();
    await client.handshake();

    await expectLater(
      client.convert(
        requestId: 'bad-json',
        inputPdf: '/tmp/in.pdf',
        outputXlsx: '/tmp/out.xlsx',
      ).drain<void>(),
      throwsA(
        isA<ConversionFailure>().having(
          (error) => error.code,
          'code',
          'MALFORMED_EVENT',
        ),
      ),
    );

    await client.close();
  });

  test('worker crash mid-conversion becomes WORKER_CRASHED failure', () async {
    final client = ConversionWorkerClient(
      locator: const WorkerLocator(environment: '/fake/worker'),
      processStarter: (
        executable,
        arguments, {
        String? workingDirectory,
        ProcessStartMode mode = ProcessStartMode.normal,
      }) async {
        return FakeWorkerProcess(crashAfterProgress: true);
      },
    );

    await client.start();
    await client.handshake();

    await expectLater(
      client.convert(
        requestId: 'crash',
        inputPdf: '/tmp/in.pdf',
        outputXlsx: '/tmp/out.xlsx',
      ).drain<void>(),
      throwsA(
        isA<ConversionFailure>().having(
          (error) => error.code,
          'code',
          'WORKER_CRASHED',
        ),
      ),
    );

    await client.close();
  });

  test('stderr diagnostics are retained without document contents', () async {
    late FakeWorkerProcess fake;
    final client = ConversionWorkerClient(
      locator: const WorkerLocator(environment: '/fake/worker'),
      processStarter: (
        executable,
        arguments, {
        String? workingDirectory,
        ProcessStartMode mode = ProcessStartMode.normal,
      }) async {
        fake = FakeWorkerProcess();
        return fake;
      },
    );

    await client.start();
    fake.emitStderr('worker_version=0.1.0-fake stage=extracting');
    await client.handshake();
    await client.close();

    expect(client.diagnosticsLines, contains('worker_version=0.1.0-fake stage=extracting'));
  });
}
