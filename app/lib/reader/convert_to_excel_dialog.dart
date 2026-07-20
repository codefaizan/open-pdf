import 'package:flutter/material.dart';
import 'package:open_pdf/services/conversion_protocol.dart';

class ConvertToExcelOptions {
  const ConvertToExcelOptions({this.pages});

  final String? pages;
}

Future<ConvertToExcelOptions?> showConvertToExcelDialog(
  BuildContext context, {
  required int pageCount,
}) {
  return showDialog<ConvertToExcelOptions>(
    context: context,
    builder: (context) => ConvertToExcelDialog(pageCount: pageCount),
  );
}

class ConvertToExcelDialog extends StatefulWidget {
  const ConvertToExcelDialog({
    required this.pageCount,
    super.key,
  });

  final int pageCount;

  @override
  State<ConvertToExcelDialog> createState() => _ConvertToExcelDialogState();
}

class _ConvertToExcelDialogState extends State<ConvertToExcelDialog> {
  final _pagesController = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _pagesController.dispose();
    super.dispose();
  }

  void _submit() {
    final pages = _pagesController.text.trim();
    if (pages.isNotEmpty && !isValidPageRange(pages)) {
      setState(() => _validationError = 'Enter a valid page range, such as 1-3,5.');
      return;
    }

    Navigator.of(context).pop(
      ConvertToExcelOptions(pages: pages.isEmpty ? null : pages),
    );
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('convert_to_excel_dialog'),
      title: const Text('Convert to Excel'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'All ${widget.pageCount} pages will be converted unless you enter a page range.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('convert_page_range_field'),
            controller: _pagesController,
            decoration: InputDecoration(
              labelText: 'Page range (optional)',
              hintText: '1-3,5',
              errorText: _validationError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_validationError != null) {
                setState(() => _validationError = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('convert_cancel'),
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('convert_continue'),
          onPressed: _submit,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

Future<bool?> confirmWorkbookOverwrite(
  BuildContext context, {
  required String destinationPath,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('convert_overwrite_dialog'),
      title: const Text('Replace existing workbook?'),
      content: SelectableText(
        'A workbook already exists at:\n$destinationPath\n\nReplace it?',
      ),
      actions: [
        TextButton(
          key: const Key('convert_overwrite_cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Choose another location'),
        ),
        FilledButton(
          key: const Key('convert_overwrite_confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
}
