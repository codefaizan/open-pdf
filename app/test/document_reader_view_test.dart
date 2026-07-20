import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/reader/document_reader_view.dart';
import 'package:open_pdf/reader/open_document.dart';

void main() {
  testWidgets('DocumentReaderView mounts without crashing before viewer is ready', (
    tester,
  ) async {
    // Regression for pdfrx #576: PdfTextSearcher must not be constructed until
    // PdfViewerController.isReady (onViewerReady), or initState throws.
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentReaderView(
          document: OpenDocument('/nonexistent/document.pdf'),
          onClose: () {},
          onOpenPdf: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
