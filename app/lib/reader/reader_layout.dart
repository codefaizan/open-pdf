import 'package:flutter/material.dart';
import 'package:open_pdf/reader/reader_toolbar.dart';

class ReaderLayout extends StatelessWidget {
  const ReaderLayout({
    required this.documentName,
    required this.onClose,
    required this.onOpenPdf,
    required this.onConvertToExcel,
    required this.body,
    this.sidebar,
    this.controlBar,
    this.searchBar,
    this.convertEnabled = true,
    this.conversionOverlay,
    super.key,
  });

  final String documentName;
  final VoidCallback onClose;
  final VoidCallback onOpenPdf;
  final VoidCallback onConvertToExcel;
  final Widget body;
  final Widget? sidebar;
  final Widget? controlBar;
  final Widget? searchBar;
  final bool convertEnabled;
  final Widget? conversionOverlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            ReaderToolbar(
              documentName: documentName,
              onOpenPdf: onOpenPdf,
              onClose: onClose,
              onConvertToExcel: onConvertToExcel,
              convertEnabled: convertEnabled,
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
        ),
        if (conversionOverlay != null)
          Positioned(
            left: 16,
            bottom: 16,
            child: conversionOverlay!,
          ),
      ],
    );
  }
}
