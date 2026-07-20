import 'package:flutter/material.dart';

class ReaderSearchBar extends StatefulWidget {
  const ReaderSearchBar({
    required this.query,
    required this.matchLabel,
    required this.onQueryChanged,
    required this.onPreviousMatch,
    required this.onNextMatch,
    required this.onClose,
    this.searchFieldFocusNode,
    super.key,
  });

  final String query;
  final String matchLabel;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onPreviousMatch;
  final VoidCallback onNextMatch;
  final VoidCallback onClose;
  final FocusNode? searchFieldFocusNode;

  @override
  State<ReaderSearchBar> createState() => _ReaderSearchBarState();
}

class _ReaderSearchBarState extends State<ReaderSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant ReaderSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: const Key('reader_search_bar'),
      color: theme.colorScheme.surfaceContainerLow,
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
              Expanded(
                child: TextField(
                  key: const Key('reader_search_field'),
                  focusNode: widget.searchFieldFocusNode,
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Search in document',
                    prefixIcon: Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: widget.onQueryChanged,
                  onSubmitted: widget.onQueryChanged,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.matchLabel,
                style: theme.textTheme.bodyMedium,
              ),
              IconButton(
                key: const Key('reader_search_prev'),
                tooltip: 'Previous match',
                onPressed: widget.onPreviousMatch,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                key: const Key('reader_search_next'),
                tooltip: 'Next match',
                onPressed: widget.onNextMatch,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton(
                tooltip: 'Close search',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
