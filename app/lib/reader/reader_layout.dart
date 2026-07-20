import 'package:flutter/material.dart';
import 'package:open_pdf/reader/reader_toolbar.dart';

class ReaderLayout extends StatelessWidget {
  const ReaderLayout({
    required this.documentName,
    required this.onClose,
    required this.onOpenPdf,
    required this.body,
    this.sidebar,
    super.key,
  });

  final String documentName;
  final VoidCallback onClose;
  final VoidCallback onOpenPdf;
  final Widget body;
  final Widget? sidebar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReaderToolbar(
          documentName: documentName,
          onOpenPdf: onOpenPdf,
          onClose: onClose,
        ),
        Expanded(
          child: Row(
            children: [
              if (sidebar != null)
                SizedBox(
                  width: 180,
                  child: sidebar,
                ),
              Expanded(child: body),
            ],
          ),
        ),
      ],
    );
  }
}
