import 'package:flutter/material.dart';
import 'package:open_pdf/reader/document_error_view.dart';
import 'package:open_pdf/reader/document_reader_view.dart';
import 'package:open_pdf/reader/empty_reader_view.dart';
import 'package:open_pdf/reader/open_document.dart';
import 'package:open_pdf/services/document_path.dart';
import 'package:open_pdf/services/pdf_open_service.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    this.pdfOpenService = const NativePdfOpenService(),
    this.initialErrorMessage,
    super.key,
  });

  final PdfOpenService pdfOpenService;
  final String? initialErrorMessage;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  OpenDocument? _document;
  late String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialErrorMessage;
  }

  Future<void> _openPdf() async {
    final path = await widget.pdfOpenService.pickPdfFile();
    if (!mounted || path == null) {
      return;
    }
    await _openPath(path);
  }

  Future<void> _openPath(String path) async {
    setState(() {
      _document = null;
      _errorMessage = null;
    });

    final validationError = await validatePdfPath(path);
    if (!mounted) {
      return;
    }

    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() => _document = OpenDocument(path));
  }

  void _closeDocument() {
    setState(() {
      _document = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return DocumentErrorView(
        message: _errorMessage!,
        onOpenPdf: _openPdf,
      );
    }

    final document = _document;
    if (document == null) {
      return EmptyReaderView(onOpenPdf: _openPdf);
    }

    return DocumentReaderView(
      document: document,
      onClose: _closeDocument,
      onOpenPdf: _openPdf,
    );
  }
}
