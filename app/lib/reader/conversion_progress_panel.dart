import 'package:flutter/material.dart';
import 'package:open_pdf/services/conversion_worker_client.dart';

class ConversionProgressPanel extends StatelessWidget {
  const ConversionProgressPanel({
    required this.progress,
    required this.progressEvents,
    this.onCancel,
    super.key,
  });

  final ConversionProgress progress;
  final List<ConversionProgress> progressEvents;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: const Key('conversion_progress_panel'),
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainerHighest,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Converting to Excel',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress.percent / 100),
              const SizedBox(height: 8),
              Text(
                progress.message,
                key: Key('conversion_progress_message_${progress.stage}'),
              ),
              const SizedBox(height: 4),
              Text(
                '${progress.percent}%',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ...progressEvents.map(
                (event) => Text(
                  '${event.percent}% · ${event.message}',
                  key: Key(
                    'conversion_progress_step_${event.stage}_${event.percent}',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('conversion_cancel'),
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
