import 'package:flutter/material.dart';

class EmptyReaderView extends StatelessWidget {
  const EmptyReaderView({
    required this.onOpenPdf,
    super.key,
  });

  final VoidCallback onOpenPdf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Open PDF',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Choose a PDF from your computer to start reading.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              key: const Key('empty_open_pdf'),
              onPressed: onOpenPdf,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Open PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
