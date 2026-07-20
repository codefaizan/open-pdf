import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/reader/document_error_view.dart';
import 'package:open_pdf/reader/empty_reader_view.dart';
import 'package:open_pdf/reader/reader_layout.dart';
import 'package:open_pdf/reader/reader_screen.dart';
import 'package:open_pdf/services/pdf_open_service.dart';

void main() {
  group('empty state', () {
    testWidgets('shows one clear action to open a PDF', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmptyReaderView(onOpenPdf: () {}),
        ),
      );

      expect(find.byKey(const Key('empty_open_pdf')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Open PDF'), findsOneWidget);
    });
  });

  group('reader layout', () {
    testWidgets('includes toolbar, thumbnail rail, and document canvas', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderLayout(
            documentName: 'sample.pdf',
            onClose: () {},
            onOpenPdf: () {},
            body: const Placeholder(key: Key('reader_document_canvas')),
          sidebar: const SizedBox(key: Key('reader_thumbnail_rail')),
          ),
        ),
      );

      expect(find.byKey(const Key('reader_toolbar')), findsOneWidget);
      expect(find.byKey(const Key('reader_thumbnail_rail')), findsOneWidget);
      expect(find.byKey(const Key('reader_document_canvas')), findsOneWidget);
      expect(find.text('sample.pdf'), findsOneWidget);
    });
  });

  group('document error', () {
    testWidgets('shows recoverable error with open action', (tester) async {
      var openTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DocumentErrorView(
            message: 'This PDF could not be opened.',
            onOpenPdf: () => openTapped = true,
          ),
        ),
      );

      expect(find.byKey(const Key('document_error_view')), findsOneWidget);
      expect(find.text('This PDF could not be opened.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('error_open_pdf')));
      await tester.pump();

      expect(openTapped, isTrue);
    });
  });

  group('reader screen', () {
    testWidgets('starts in empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderScreen(pdfOpenService: _FakePdfOpenService()),
        ),
      );

      expect(find.byKey(const Key('empty_open_pdf')), findsOneWidget);
    });

    testWidgets('shows error for unreadable PDF paths', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderScreen(
            initialErrorMessage: 'The selected file could not be found.',
          ),
        ),
      );

      expect(find.byKey(const Key('document_error_view')), findsOneWidget);
      expect(find.textContaining('could not be found'), findsOneWidget);
    });

    testWidgets('can retry after validation error', (tester) async {
      final service = _SequencePdfOpenService([
        null,
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ReaderScreen(
            pdfOpenService: service,
            initialErrorMessage: 'The selected file could not be found.',
          ),
        ),
      );

      expect(find.byKey(const Key('document_error_view')), findsOneWidget);

      await tester.tap(find.byKey(const Key('error_open_pdf')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('document_error_view')), findsOneWidget);
    });

    testWidgets('close control is available while reading', (tester) async {
      var closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ReaderLayout(
            documentName: 'sample.pdf',
            onClose: () => closed = true,
            onOpenPdf: () {},
            body: const SizedBox(),
            sidebar: const SizedBox(key: Key('reader_thumbnail_rail')),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('reader_close_document')));
      expect(closed, isTrue);
    });
  });
}

class _FakePdfOpenService implements PdfOpenService {
  @override
  Future<String?> pickPdfFile() async => null;
}

class _SequencePdfOpenService implements PdfOpenService {
  _SequencePdfOpenService(this.paths);

  final List<String?> paths;
  var index = 0;

  @override
  Future<String?> pickPdfFile() async {
    if (index >= paths.length) return null;
    return paths[index++];
  }
}
