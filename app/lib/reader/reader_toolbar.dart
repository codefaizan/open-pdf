import 'package:flutter/material.dart';

class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    required this.documentName,
    required this.onOpenPdf,
    required this.onClose,
    required this.onConvertToExcel,
    this.convertEnabled = true,
    super.key,
  });

  final String documentName;
  final VoidCallback onOpenPdf;
  final VoidCallback onClose;
  final VoidCallback onConvertToExcel;
  final bool convertEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: const Key('reader_toolbar'),
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: onOpenPdf,
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: const Text('Open'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('reader_close_document'),
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Close'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const Key('reader_convert_to_excel'),
                onPressed: convertEnabled ? onConvertToExcel : null,
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text('Convert to Excel'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  documentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
