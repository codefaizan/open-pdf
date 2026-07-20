import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/reader/conversion_progress_panel.dart';
import 'package:open_pdf/services/conversion_worker_client.dart';
import 'package:open_pdf/reader/document_error_view.dart';
import 'package:open_pdf/reader/document_outline_panel.dart';
import 'package:open_pdf/reader/empty_reader_view.dart';
import 'package:open_pdf/reader/password_prompt_dialog.dart';
import 'package:open_pdf/reader/reader_control_bar.dart';
import 'package:open_pdf/reader/reader_layout.dart';
import 'package:open_pdf/reader/reader_navigation_controls.dart';
import 'package:open_pdf/reader/reader_screen.dart';
import 'package:open_pdf/reader/reader_search_bar.dart';
import 'package:open_pdf/reader/reader_tab_bar.dart';
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
            onConvertToExcel: () {},
            body: const Placeholder(key: Key('reader_document_canvas')),
            sidebar: const SizedBox(key: Key('reader_thumbnail_rail')),
          ),
        ),
      );

      expect(find.byKey(const Key('reader_toolbar')), findsOneWidget);
      expect(find.byKey(const Key('reader_thumbnail_rail')), findsOneWidget);
      expect(find.byKey(const Key('reader_document_canvas')), findsOneWidget);
      expect(find.byKey(const Key('reader_convert_to_excel')), findsOneWidget);
      expect(find.text('sample.pdf'), findsOneWidget);
    });

    testWidgets('convert action is disabled while conversion runs', (tester) async {
      var convertTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ReaderLayout(
            documentName: 'sample.pdf',
            onClose: () {},
            onOpenPdf: () {},
            onConvertToExcel: () => convertTapped = true,
            convertEnabled: false,
            conversionOverlay: ConversionProgressPanel(
              progress: const ConversionProgress(
                stage: 'extracting',
                percent: 40,
                message: 'Extracting tables',
              ),
              progressEvents: const [
                ConversionProgress(
                  stage: 'starting',
                  percent: 5,
                  message: 'Starting conversion',
                ),
                ConversionProgress(
                  stage: 'extracting',
                  percent: 40,
                  message: 'Extracting tables',
                ),
              ],
            ),
            body: const SizedBox(key: Key('reader_document_canvas')),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('reader_convert_to_excel')));
      await tester.pump();

      expect(convertTapped, isFalse);
      expect(find.byKey(const Key('conversion_progress_panel')), findsOneWidget);
      expect(find.text('5% · Starting conversion'), findsOneWidget);
      expect(find.text('40% · Extracting tables'), findsOneWidget);
    });

    testWidgets('reading state shows navigation and zoom controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderLayout(
              documentName: 'sample.pdf',
              onClose: () {},
              onOpenPdf: () {},
              onConvertToExcel: () {},
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
            onConvertToExcel: () {},
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
            onConvertToExcel: () {},
            body: const SizedBox(),
            sidebar: const SizedBox(key: Key('reader_thumbnail_rail')),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('reader_close_document')));
      expect(closed, isTrue);
    });

    testWidgets('opens multiple PDFs as tabs and can switch between them', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('open-pdf-tabs-');
      addTearDown(() {
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      });

      final first = File('${dir.path}/first.pdf')
        ..writeAsBytesSync(const [0x25, 0x50, 0x44, 0x46]);
      final second = File('${dir.path}/second.pdf')
        ..writeAsBytesSync(const [0x25, 0x50, 0x44, 0x46]);
      final service = _SequencePdfOpenService([second.path]);

      await tester.pumpWidget(
        MaterialApp(
          home: ReaderScreen(
            pdfOpenService: service,
            initialPdfPath: first.path,
          ),
        ),
      );
      await tester.pump(); // post-frame open + sync validation

      expect(find.byKey(const Key('reader_tab_bar')), findsOneWidget);
      expect(find.byKey(const Key('reader_tab_0')), findsOneWidget);
      expect(find.text('first.pdf'), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('reader_toolbar')),
          matching: find.text('Open'),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('reader_tab_0')), findsOneWidget);
      expect(find.byKey(const Key('reader_tab_1')), findsOneWidget);
      expect(find.text('second.pdf'), findsWidgets);

      await tester.tap(find.byKey(const Key('reader_tab_0')));
      await tester.pump();

      expect(find.text('first.pdf'), findsWidgets);
    });

    testWidgets('closing the last tab returns to the empty state', (tester) async {
      final dir = Directory.systemTemp.createTempSync('open-pdf-tabs-close-');
      addTearDown(() {
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      });

      final pdf = File('${dir.path}/alone.pdf')
        ..writeAsBytesSync(const [0x25, 0x50, 0x44, 0x46]);

      await tester.pumpWidget(
        MaterialApp(
          home: ReaderScreen(initialPdfPath: pdf.path),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('reader_tab_bar')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reader_tab_close_0')));
      await tester.pump();

      expect(find.byKey(const Key('empty_open_pdf')), findsOneWidget);
      expect(find.byKey(const Key('reader_tab_bar')), findsNothing);
    });
  });

  group('reader tab bar', () {
    testWidgets('selects and closes tabs', (tester) async {
      var selected = 0;
      var closed = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderTabBar(
              titles: const ['a.pdf', 'b.pdf'],
              activeIndex: selected,
              onSelect: (index) => selected = index,
              onClose: (index) => closed = index,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('reader_tab_bar')), findsOneWidget);
      expect(find.text('a.pdf'), findsOneWidget);
      expect(find.text('b.pdf'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reader_tab_1')));
      expect(selected, 1);

      await tester.tap(find.byKey(const Key('reader_tab_close_0')));
      expect(closed, 0);
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
