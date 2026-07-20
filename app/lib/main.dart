import 'package:flutter/material.dart';
import 'package:open_pdf/app.dart';
import 'package:pdfrx/pdfrx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  const autoOpen = String.fromEnvironment('OPEN_PDF_AUTO_OPEN');
  runApp(
    OpenPdfApp(
      initialPdfPath: autoOpen.isEmpty ? null : autoOpen,
    ),
  );
}
