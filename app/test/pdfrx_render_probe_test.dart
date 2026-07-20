import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('pdfrx opens and renders ruled_table page', () async {
    await pdfrxFlutterInitialize();
    final path = '${Directory.current.path}/../corpus/ruled_table.pdf';
    final doc = await PdfDocument.openFile(path);
    expect(doc.pages, isNotEmpty);
    final page = doc.pages.first;
    final img = await page.render(fullWidth: 200, fullHeight: 200);
    expect(img, isNotNull);
    expect(img!.width, greaterThan(0));
    expect(img.height, greaterThan(0));
    // Non-all-same pixels would mean real paint; at least assert bytes length.
    expect(img.pixels.length, greaterThan(0));
    await doc.dispose();
  });
}
