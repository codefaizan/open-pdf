import 'package:flutter/material.dart';
import 'package:open_pdf/reader/reader_screen.dart';

class OpenPdfApp extends StatelessWidget {
  const OpenPdfApp({
    this.initialPdfPath,
    super.key,
  });

  /// Optional path opened on launch (debug/smoke only).
  final String? initialPdfPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open PDF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F5A96),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8AB4F8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ReaderScreen(initialPdfPath: initialPdfPath),
    );
  }
}
