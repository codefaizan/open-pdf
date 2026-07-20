import 'package:flutter/material.dart';

Future<String?> showPasswordPromptDialog(
  BuildContext context, {
  String? errorMessage,
}) {
  return showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PasswordPromptDialog(errorMessage: errorMessage),
  );
}

class PasswordPromptDialog extends StatefulWidget {
  const PasswordPromptDialog({
    this.errorMessage,
    super.key,
  });

  final String? errorMessage;

  @override
  State<PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<PasswordPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      key: const Key('password_prompt_dialog'),
      title: const Text('Enter password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.errorMessage != null) ...[
            Text(
              widget.errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            key: const Key('password_field'),
            controller: _controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('password_cancel'),
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('password_submit'),
          onPressed: _submit,
          child: const Text('Open'),
        ),
      ],
    );
  }
}
