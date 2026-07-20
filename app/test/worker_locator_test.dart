import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/services/worker_locator.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('open-pdf-locator-');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('finds frozen worker from macOS debug executable path when cwd is unrelated', () {
    // Mirrors Flutter macOS debug layout; tickets.md is 9 levels above MacOS/.
    final macosDir = Directory(
      '${tempDir.path}/app/build/macos/Build/Products/Debug/'
      'Open PDF.app/Contents/MacOS',
    )..createSync(recursive: true);
    File('${tempDir.path}/tickets.md').writeAsStringSync('');
    final worker = File(
      '${tempDir.path}/worker/dist/open_pdf_worker/open_pdf_worker',
    )..createSync(recursive: true);
    worker.writeAsStringSync('');

    final locator = WorkerLocator(
      environment: '',
      searchRoots: [Directory.systemTemp.path, macosDir.path],
    );

    expect(locator.resolveLaunchCommand(), [worker.path]);
  });

  test('honors runtime OPEN_PDF_WORKER_EXECUTABLE when compile-time define is empty', () {
    final worker = File('${tempDir.path}/custom_worker')..writeAsStringSync('');
    final locator = WorkerLocator(
      environment: '',
      runtimeEnvironment: {'OPEN_PDF_WORKER_EXECUTABLE': worker.path},
      searchRoots: [Directory.systemTemp.path],
    );

    expect(locator.resolveLaunchCommand(), [worker.path]);
  });
}
