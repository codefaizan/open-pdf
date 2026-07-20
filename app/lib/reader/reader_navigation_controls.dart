import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReaderNavigationControls extends StatefulWidget {
  const ReaderNavigationControls({
    required this.currentPage,
    required this.pageCount,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSubmitted,
    super.key,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final ValueChanged<int> onPageSubmitted;

  @override
  State<ReaderNavigationControls> createState() => _ReaderNavigationControlsState();
}

class _ReaderNavigationControlsState extends State<ReaderNavigationControls> {
  late final TextEditingController _pageController;
  late final FocusNode _pageFocusNode;

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController(text: '${widget.currentPage}');
    _pageFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant ReaderNavigationControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage && !_pageFocusNode.hasFocus) {
      _pageController.text = '${widget.currentPage}';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageFocusNode.dispose();
    super.dispose();
  }

  void _submitPage() {
    final value = int.tryParse(_pageController.text.trim());
    if (value == null) {
      _pageController.text = '${widget.currentPage}';
      return;
    }
    final clamped = value.clamp(1, widget.pageCount);
    _pageController.text = '$clamped';
    widget.onPageSubmitted(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      key: const Key('reader_navigation_controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('reader_prev_page'),
          tooltip: 'Previous page',
          onPressed: widget.currentPage > 1 ? widget.onPreviousPage : null,
          icon: const Icon(Icons.chevron_left),
        ),
        SizedBox(
          width: 48,
          child: TextField(
            key: const Key('reader_page_field'),
            controller: _pageController,
            focusNode: _pageFocusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submitPage(),
            onEditingComplete: _submitPage,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '/ ${widget.pageCount}',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        IconButton(
          key: const Key('reader_next_page'),
          tooltip: 'Next page',
          onPressed: widget.currentPage < widget.pageCount ? widget.onNextPage : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
