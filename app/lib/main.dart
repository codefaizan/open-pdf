import 'package:flutter/material.dart';
import 'package:open_pdf/app.dart';
import 'package:pdfrx/pdfrx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  runApp(const OpenPdfApp());
}
