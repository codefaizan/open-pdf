import 'package:pdfrx/pdfrx.dart';

/// An opened PDF document backed by a shared [PdfDocumentRef].
class OpenDocument {
  OpenDocument(this.path)
    : ref = PdfDocumentRefFile(
        path,
        useProgressiveLoading: true,
      );

  final String path;
  final PdfDocumentRefFile ref;
}

String friendlyPdfError(Object error) {
  final message = error.toString();
  if (message.contains('password') || message.contains('Password')) {
    return 'This PDF is password-protected.';
  }
  if (message.contains('format') || message.contains('Format')) {
    return 'This file does not appear to be a valid PDF.';
  }
  return 'This PDF could not be opened.';
}
