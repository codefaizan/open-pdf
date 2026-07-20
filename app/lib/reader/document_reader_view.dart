import 'package:flutter/material.dart';
import 'package:open_pdf/reader/document_error_view.dart';
import 'package:open_pdf/reader/open_document.dart';
import 'package:open_pdf/reader/reader_layout.dart';
import 'package:open_pdf/reader/thumbnail_rail.dart';
import 'package:open_pdf/services/document_path.dart';
import 'package:pdfrx/pdfrx.dart';

class DocumentReaderView extends StatefulWidget {
  const DocumentReaderView({
    required this.document,
    required this.onClose,
    required this.onOpenPdf,
    super.key,
  });

  final OpenDocument document;
  final VoidCallback onClose;
  final VoidCallback onOpenPdf;

  @override
  State<DocumentReaderView> createState() => _DocumentReaderViewState();
}

class _DocumentReaderViewState extends State<DocumentReaderView> {
  final _viewerController = PdfViewerController();
  var _currentPage = 1;

  Future<void> _goToPage(int pageNumber) async {
    setState(() => _currentPage = pageNumber);
    if (_viewerController.isReady) {
      await _viewerController.goToPage(pageNumber: pageNumber);
    }
  }

  Widget _buildLayout({
    required Widget body,
    Widget? sidebar,
  }) {
    return ReaderLayout(
      documentName: documentDisplayName(widget.document.path),
      onClose: widget.onClose,
      onOpenPdf: widget.onOpenPdf,
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

        return _buildLayout(
          sidebar: ThumbnailRail(
            document: pdfDocument,
            currentPage: _currentPage,
            onPageSelected: _goToPage,
          ),
          body: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: PdfViewer(
              widget.document.ref,
              key: const Key('reader_document_canvas'),
              controller: _viewerController,
              params: PdfViewerParams(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                onPageChanged: (pageNumber) {
                  if (pageNumber != null && pageNumber != _currentPage) {
                    setState(() => _currentPage = pageNumber);
                  }
                },
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
