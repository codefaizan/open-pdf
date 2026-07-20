import 'package:flutter/material.dart';

Future<void> showConversionCompleteDialog(
  BuildContext context, {
  required String outputPath,
  required Future<void> Function() onOpen,
  required Future<void> Function() onReveal,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => ConversionCompleteDialog(
      outputPath: outputPath,
      onOpen: onOpen,
      onReveal: onReveal,
    ),
  );
}

class ConversionCompleteDialog extends StatelessWidget {
  const ConversionCompleteDialog({
    required this.outputPath,
    required this.onOpen,
    required this.onReveal,
    super.key,
  });

  final String outputPath;
  final Future<void> Function() onOpen;
  final Future<void> Function() onReveal;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('conversion_complete_dialog'),
      title: const Text('Conversion complete'),
      content: SelectableText(
        'Workbook saved to:\n$outputPath',
      ),
      actions: [
        TextButton(
          key: const Key('conversion_complete_reveal'),
          onPressed: () async {
            await onReveal();
          },
          child: const Text('Show in folder'),
        ),
        FilledButton(
          key: const Key('conversion_complete_open'),
          onPressed: () async {
            await onOpen();
          },
          child: const Text('Open workbook'),
        ),
      ],
    );
  }
}

Future<void> showConversionErrorDialog(
  BuildContext context, {
  required String message,
  String? diagnostics,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('conversion_error_dialog'),
      title: const Text('Conversion failed'),
      content: SelectableText(
        diagnostics == null ? message : '$message\n\nDiagnostics: $diagnostics',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
