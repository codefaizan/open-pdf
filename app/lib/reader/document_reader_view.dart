import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_pdf/reader/convert_to_excel_dialog.dart';
import 'package:open_pdf/reader/conversion_complete_dialog.dart';
import 'package:open_pdf/reader/conversion_progress_panel.dart';
import 'package:open_pdf/reader/document_error_view.dart';
import 'package:open_pdf/reader/document_outline_panel.dart';
import 'package:open_pdf/reader/open_document.dart';
import 'package:open_pdf/reader/reader_control_bar.dart';
import 'package:open_pdf/reader/reader_layout.dart';
import 'package:open_pdf/reader/reader_navigation_controls.dart';
import 'package:open_pdf/reader/reader_search_bar.dart';
import 'package:open_pdf/reader/reader_zoom_controls.dart';
import 'package:open_pdf/reader/thumbnail_rail.dart';
import 'package:open_pdf/services/conversion_service.dart';
import 'package:open_pdf/services/conversion_worker_client.dart';
import 'package:open_pdf/services/document_path.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentReaderView extends StatefulWidget {
  const DocumentReaderView({
    required this.document,
    required this.onClose,
    required this.onOpenPdf,
    this.onSearchHandlerReady,
    this.conversionService,
    this.workbookActions = const WorkbookActions(),
    super.key,
  });

  final OpenDocument document;
  final VoidCallback onClose;
  final VoidCallback onOpenPdf;
  final ValueChanged<VoidCallback>? onSearchHandlerReady;
  final ConversionService? conversionService;
  final WorkbookActions workbookActions;

  @override
  State<DocumentReaderView> createState() => _DocumentReaderViewState();
}

class _DocumentReaderViewState extends State<DocumentReaderView> {
  final _viewerController = PdfViewerController();
  final _searchFieldFocusNode = FocusNode();
  late final PdfTextSearcher _textSearcher;

  var _currentPage = 1;
  var _pageCount = 1;
  var _searchVisible = false;
  var _searchQuery = '';
  var _outlineVisible = false;
  var _converting = false;
  ConversionProgress? _conversionProgress;
  List<ConversionProgress> _conversionProgressEvents = const [];
  List<PdfOutlineNode>? _outline;

  ConversionService get _conversionService =>
      widget.conversionService ?? ConversionService();

  @override
  void initState() {
    super.initState();
    _textSearcher = PdfTextSearcher(_viewerController)..addListener(_onSearchUpdated);
    widget.onSearchHandlerReady?.call(_showSearchFromShortcut);
  }

  @override
  void dispose() {
    _textSearcher.removeListener(_onSearchUpdated);
    _textSearcher.dispose();
    _searchFieldFocusNode.dispose();
    super.dispose();
  }

  void _onSearchUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _goToPage(int pageNumber) async {
    setState(() => _currentPage = pageNumber);
    if (_viewerController.isReady) {
      await _viewerController.goToPage(pageNumber: pageNumber);
    }
  }

  Future<void> _zoomIn() async {
    if (_viewerController.isReady) {
      await _viewerController.zoomUp();
    }
  }

  Future<void> _zoomOut() async {
    if (_viewerController.isReady) {
      await _viewerController.zoomDown();
    }
  }

  Future<void> _fitWidth() async {
    if (!_viewerController.isReady) return;
    final matrix = _viewerController.calcMatrixFitWidthForPage(
      pageNumber: _currentPage,
    );
    if (matrix != null) {
      await _viewerController.goTo(matrix);
    }
  }

  Future<void> _fitPage() async {
    if (!_viewerController.isReady) return;
    final matrix = _viewerController.calcMatrixForFit(pageNumber: _currentPage);
    if (matrix != null) {
      await _viewerController.goTo(matrix);
    }
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchQuery = '';
        _textSearcher.resetTextSearch();
      }
    });
    if (_searchVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFieldFocusNode.requestFocus();
      });
    }
  }

  void _showSearchFromShortcut() {
    if (!_searchVisible) {
      _toggleSearch();
    } else {
      _searchFieldFocusNode.requestFocus();
    }
  }

  void _updateSearchQuery(String query) {
    setState(() => _searchQuery = query);
    if (query.trim().isEmpty) {
      _textSearcher.resetTextSearch();
      return;
    }
    _textSearcher.startTextSearch(
      query,
      caseInsensitive: true,
      goToFirstMatch: true,
    );
  }

  String _searchMatchLabel() {
    final matches = _textSearcher.matches;
    if (_searchQuery.trim().isEmpty || matches.isEmpty) {
      return _textSearcher.isSearching ? 'Searching…' : 'No matches';
    }

    final index = _textSearcher.currentIndex;
    if (index == null) {
      return '${matches.length} matches';
    }

    return '${index + 1} of ${matches.length}';
  }

  Future<void> _handleLinkTap(PdfLink link) async {
    if (link.dest != null) {
      await _viewerController.goToDest(link.dest);
      return;
    }

    final url = link.url;
    if (url == null) {
      return;
    }

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open link?'),
        content: SelectableText(url.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    if (shouldOpen == true && await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _handleOutlineDestination(Object? destination) async {
    if (destination is PdfDest) {
      await _viewerController.goToDest(destination);
    }
  }

  Future<void> _startConvertToExcel() async {
    if (_converting) {
      return;
    }

    final options = await showConvertToExcelDialog(
      context,
      pageCount: _pageCount,
    );
    if (!mounted || options == null) {
      return;
    }

    var destination = await _conversionService.pickDestination(
      widget.document.path,
    );
    if (!mounted || destination == null) {
      return;
    }

    var outputPath = destination;
    var replaceExisting = false;
    if (_conversionService.destinationExists(destination)) {
      final confirmed = await confirmWorkbookOverwrite(
        context,
        destinationPath: destination,
      );
      if (!mounted || confirmed != true) {
        return;
      }
      replaceExisting = true;
      outputPath = _conversionService.temporaryReplacementPath(destination);
    }

    setState(() {
      _converting = true;
      _conversionProgress = null;
      _conversionProgressEvents = const [];
    });

    try {
      await for (final event in _conversionService.runConversion(
        ConversionRequest(
          inputPdf: widget.document.path,
          outputXlsx: outputPath,
          pages: options.pages,
        ),
      )) {
        if (!mounted) {
          return;
        }

        if (event is ConversionProgress) {
          setState(() {
            _conversionProgress = event;
            _conversionProgressEvents = [..._conversionProgressEvents, event];
          });
        } else if (event is ConversionComplete) {
          if (!mounted) {
            return;
          }

          final savedPath = replaceExisting
              ? await _conversionService.finalizeReplacement(
                  temporaryPath: event.outputPath,
                  destinationPath: destination,
                )
              : event.outputPath;

          if (!mounted) {
            return;
          }

          setState(() {
            _converting = false;
            _conversionProgress = null;
            _conversionProgressEvents = const [];
          });

          await showConversionCompleteDialog(
            context,
            outputPath: savedPath,
            onOpen: () => widget.workbookActions.openWorkbook(savedPath),
            onReveal: () => widget.workbookActions.revealWorkbook(savedPath),
          );
        }
      }
    } on ConversionFailure catch (error) {
      if (replaceExisting && File(outputPath).existsSync()) {
        await File(outputPath).delete();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _converting = false;
        _conversionProgress = null;
        _conversionProgressEvents = const [];
      });
      await showConversionErrorDialog(context, message: error.message);
    } catch (error) {
      if (replaceExisting && File(outputPath).existsSync()) {
        await File(outputPath).delete();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _converting = false;
        _conversionProgress = null;
        _conversionProgressEvents = const [];
      });
      await showConversionErrorDialog(
        context,
        message: 'Conversion failed: $error',
      );
    }
  }

  Widget? _buildConversionOverlay() {
    if (!_converting || _conversionProgressEvents.isEmpty) {
      return null;
    }

    return ConversionProgressPanel(
      progress: _conversionProgress!,
      progressEvents: _conversionProgressEvents,
    );
  }

  Widget _buildSidebar(PdfDocument pdfDocument) {
    if (_outlineVisible && _outline != null && _outline!.isNotEmpty) {
      return DocumentOutlinePanel(
        outline: _outline!.map(PdfOutlineEntry.new).toList(),
        onDestinationSelected: _handleOutlineDestination,
      );
    }

    return ThumbnailRail(
      document: pdfDocument,
      currentPage: _currentPage,
      onPageSelected: _goToPage,
    );
  }

  Widget _buildLayout({
    required Widget body,
    Widget? sidebar,
    int? pageCount,
  }) {
    final count = pageCount ?? _pageCount;

    return ReaderLayout(
      documentName: documentDisplayName(widget.document.path),
      onClose: widget.onClose,
      onOpenPdf: widget.onOpenPdf,
      onConvertToExcel: _startConvertToExcel,
      convertEnabled: !_converting,
      conversionOverlay: _buildConversionOverlay(),
      controlBar: ReaderControlBar(
        navigation: ReaderNavigationControls(
          currentPage: _currentPage,
          pageCount: count,
          onPreviousPage: () => _goToPage(_currentPage - 1),
          onNextPage: () => _goToPage(_currentPage + 1),
          onPageSubmitted: _goToPage,
        ),
        zoom: ReaderZoomControls(
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          onFitWidth: _fitWidth,
          onFitPage: _fitPage,
        ),
        onToggleSearch: _toggleSearch,
        searchActive: _searchVisible,
        outlineAvailable: _outline != null && _outline!.isNotEmpty,
        outlineActive: _outlineVisible,
        onToggleOutline: _outline != null && _outline!.isNotEmpty
            ? () => setState(() => _outlineVisible = !_outlineVisible)
            : null,
      ),
      searchBar: _searchVisible
          ? ReaderSearchBar(
              query: _searchQuery,
              matchLabel: _searchMatchLabel(),
              onQueryChanged: _updateSearchQuery,
              onPreviousMatch: () => _textSearcher.goToPrevMatch(),
              onNextMatch: () => _textSearcher.goToNextMatch(),
              onClose: _toggleSearch,
              searchFieldFocusNode: _searchFieldFocusNode,
            )
          : null,
      sidebar: sidebar,
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PdfDocumentViewBuilder(
      documentRef: widget.document.ref,
      errorBuilder: (context, error, stackTrace) {
        return _buildLayout(
          body: DocumentErrorView(
            message: friendlyPdfError(error),
            onOpenPdf: widget.onOpenPdf,
          ),
        );
      },
      loadingBuilder: (context) {
        return _buildLayout(
          sidebar: const _ThumbnailPlaceholder(),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      builder: (context, pdfDocument) {
        if (pdfDocument == null) {
          return _buildLayout(
            sidebar: const _ThumbnailPlaceholder(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final pageCount = pdfDocument.pages.length;

        return _buildLayout(
          pageCount: pageCount,
          sidebar: _buildSidebar(pdfDocument),
          body: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: PdfViewer(
              widget.document.ref,
              key: const Key('reader_document_canvas'),
              controller: _viewerController,
              params: PdfViewerParams(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                limitRenderingCache: true,
                enableKeyboardNavigation: true,
                onViewerReady: (document, controller) async {
                  final outline = await document.loadOutline();
                  if (!mounted) return;
                  setState(() {
                    _outline = outline;
                    _pageCount = document.pages.length;
                  });
                },
                onPageChanged: (pageNumber) {
                  if (pageNumber != null && pageNumber != _currentPage) {
                    setState(() => _currentPage = pageNumber);
                  }
                },
                pagePaintCallbacks: [
                  _textSearcher.pageTextMatchPaintCallback,
                ],
                linkHandlerParams: PdfLinkHandlerParams(
                  onLinkTap: _handleLinkTap,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('reader_thumbnail_rail'),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
