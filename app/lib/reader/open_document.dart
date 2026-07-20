import 'package:flutter/material.dart';
import 'package:open_pdf/reader/password_prompt_dialog.dart';
import 'package:pdfrx/pdfrx.dart';

/// An opened PDF document backed by a shared [PdfDocumentRef].
class OpenDocument {
  OpenDocument(
    this.path, {
    PdfPasswordProvider? passwordProvider,
  }) : ref = PdfDocumentRefFile(
          path,
          useProgressiveLoading: true,
          passwordProvider: passwordProvider,
        );

  final String path;
  final PdfDocumentRefFile ref;
}

String friendlyPdfError(Object error) {
  final message = error.toString();
  if (message.contains('password') || message.contains('Password')) {
    return 'This PDF is password-protected. Enter the correct password to open it.';
  }
  if (message.contains('format') || message.contains('Format')) {
    return 'This file does not appear to be a valid PDF.';
  }
  return 'This PDF could not be opened.';
}

/// Prompts for a PDF password, retrying after rejected attempts.
Future<String?> promptForPdfPassword(
  BuildContext context, {
  required bool rejected,
}) {
  return showPasswordPromptDialog(
    context,
    errorMessage: rejected ? 'Incorrect password.' : null,
  );
}
