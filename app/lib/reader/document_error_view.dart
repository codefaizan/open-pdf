import 'package:flutter/material.dart';

class DocumentErrorView extends StatelessWidget {
  const DocumentErrorView({
    required this.message,
    required this.onOpenPdf,
    super.key,
  });

  final String message;
  final VoidCallback onOpenPdf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      key: const Key('document_error_view'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 20),
            Text(
              'Unable to open PDF',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              key: const Key('error_open_pdf'),
              onPressed: onOpenPdf,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Open another PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
