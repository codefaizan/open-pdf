import 'package:flutter/material.dart';
import 'package:open_pdf/reader/reader_toolbar.dart';

class ReaderLayout extends StatelessWidget {
  const ReaderLayout({
    required this.documentName,
    required this.onClose,
    required this.onOpenPdf,
    required this.body,
    this.sidebar,
    this.controlBar,
    this.searchBar,
    super.key,
  });

  final String documentName;
  final VoidCallback onClose;
  final VoidCallback onOpenPdf;
  final Widget body;
  final Widget? sidebar;
  final Widget? controlBar;
  final Widget? searchBar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReaderToolbar(
          documentName: documentName,
          onOpenPdf: onOpenPdf,
          onClose: onClose,
        ),
        ?controlBar,
        ?searchBar,
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
