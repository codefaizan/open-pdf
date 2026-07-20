import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/reader/document_error_view.dart';
import 'package:open_pdf/reader/document_outline_panel.dart';
import 'package:open_pdf/reader/empty_reader_view.dart';
import 'package:open_pdf/reader/password_prompt_dialog.dart';
import 'package:open_pdf/reader/reader_control_bar.dart';
import 'package:open_pdf/reader/reader_layout.dart';
import 'package:open_pdf/reader/reader_navigation_controls.dart';
import 'package:open_pdf/reader/reader_screen.dart';
import 'package:open_pdf/reader/reader_search_bar.dart';
import 'package:open_pdf/reader/reader_zoom_controls.dart';
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

    testWidgets('reading state shows navigation and zoom controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderLayout(
              documentName: 'sample.pdf',
              onClose: () {},
              onOpenPdf: () {},
              controlBar: ReaderControlBar(
                navigation: ReaderNavigationControls(
                  currentPage: 2,
                  pageCount: 10,
                  onPreviousPage: () {},
                  onNextPage: () {},
                  onPageSubmitted: (_) {},
                ),
                zoom: ReaderZoomControls(
                  onZoomIn: () {},
                  onZoomOut: () {},
                  onFitWidth: () {},
                  onFitPage: () {},
                ),
                onToggleSearch: () {},
                searchActive: false,
              ),
              body: const SizedBox(key: Key('reader_document_canvas')),
              sidebar: const SizedBox(key: Key('reader_thumbnail_rail')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('reader_navigation_controls')), findsOneWidget);
      expect(find.byKey(const Key('reader_zoom_controls')), findsOneWidget);
      expect(find.byKey(const Key('reader_prev_page')), findsOneWidget);
      expect(find.byKey(const Key('reader_next_page')), findsOneWidget);
      expect(find.byKey(const Key('reader_page_field')), findsOneWidget);
      expect(find.text('/ 10'), findsOneWidget);
      expect(find.byKey(const Key('reader_page_field')), findsOneWidget);
    });

    testWidgets('searching state shows search bar with navigation controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderLayout(
            documentName: 'sample.pdf',
            onClose: () {},
            onOpenPdf: () {},
            searchBar: ReaderSearchBar(
              query: 'invoice',
              matchLabel: '1 of 3',
              onQueryChanged: (_) {},
              onPreviousMatch: () {},
              onNextMatch: () {},
              onClose: () {},
            ),
            body: const SizedBox(key: Key('reader_document_canvas')),
            sidebar: const SizedBox(key: Key('reader_thumbnail_rail')),
          ),
        ),
      );

      expect(find.byKey(const Key('reader_search_bar')), findsOneWidget);
      expect(find.byKey(const Key('reader_search_field')), findsOneWidget);
      expect(find.byKey(const Key('reader_search_prev')), findsOneWidget);
      expect(find.byKey(const Key('reader_search_next')), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);
    });
  });

  group('zoom controls', () {
    testWidgets('expose zoom and fit actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderZoomControls(
              onZoomIn: () {},
              onZoomOut: () {},
              onFitWidth: () {},
              onFitPage: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('reader_zoom_controls')), findsOneWidget);
      expect(find.byKey(const Key('reader_zoom_in')), findsOneWidget);
      expect(find.byKey(const Key('reader_zoom_out')), findsOneWidget);
      expect(find.byKey(const Key('reader_fit_width')), findsOneWidget);
      expect(find.byKey(const Key('reader_fit_page')), findsOneWidget);
    });
  });

  group('document outline', () {
    testWidgets('shows outline entries when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentOutlinePanel(
            outline: const [
              _FakeOutlineNode(title: 'Introduction'),
              _FakeOutlineNode(title: 'Appendix'),
            ],
            onDestinationSelected: (_) {},
          ),
        ),
      );

      expect(find.byKey(const Key('reader_outline_panel')), findsOneWidget);
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Appendix'), findsOneWidget);
    });
  });

  group('password prompt', () {
    testWidgets('shows password field and recoverable actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: FilledButton(
                    onPressed: () {
                      showPasswordPromptDialog(
                        context,
                        errorMessage: 'Incorrect password.',
                      );
                    },
                    child: const Text('Prompt'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Prompt'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('password_prompt_dialog')), findsOneWidget);
      expect(find.byKey(const Key('password_field')), findsOneWidget);
      expect(find.text('Incorrect password.'), findsOneWidget);
      expect(find.byKey(const Key('password_cancel')), findsOneWidget);
      expect(find.byKey(const Key('password_submit')), findsOneWidget);
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

class _FakeOutlineNode implements OutlineEntry {
  const _FakeOutlineNode({required this.title});

  @override
  final String title;

  @override
  final List<OutlineEntry> children = const [];

  @override
  Object? get destination => 'page-1';
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
