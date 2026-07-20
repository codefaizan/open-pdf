import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/services/document_path.dart';

void main() {
  test('display name preserves non-English characters', () {
    expect(
      documentDisplayName('/Users/me/文档 报告.pdf'),
      '文档 报告.pdf',
    );
  });

  test('display name preserves spaces', () {
    expect(
      documentDisplayName('/Users/me/My Documents/sample file.pdf'),
      'sample file.pdf',
    );
  });

  test('validates existing readable files', () async {
    final dir = await Directory.systemTemp.createTemp('open-pdf-path-test');
    addTearDown(() => dir.delete(recursive: true));

    final pdfPath = '${dir.path}/文档 sample.pdf';
    await File(pdfPath).writeAsBytes(const [0x25, 0x50, 0x44, 0x46]);

    final error = await validatePdfPath(pdfPath);
    expect(error, isNull);
  });

  test('rejects missing files', () async {
    final error = await validatePdfPath('/tmp/does-not-exist-open-pdf.pdf');
    expect(error, isNotNull);
    expect(error, contains('could not be found'));
  });

  test('rejects non-PDF files', () async {
    final dir = await Directory.systemTemp.createTemp('open-pdf-path-test');
    addTearDown(() => dir.delete(recursive: true));

    final path = '${dir.path}/not-a-pdf.pdf';
    await File(path).writeAsString('hello');

    final error = await validatePdfPath(path);
    expect(error, isNotNull);
    expect(error, contains('valid PDF'));
  });
}
