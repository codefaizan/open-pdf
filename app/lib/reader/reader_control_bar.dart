import 'package:flutter/material.dart';

class ReaderControlBar extends StatelessWidget {
  const ReaderControlBar({
    required this.navigation,
    required this.zoom,
    required this.onToggleSearch,
    required this.searchActive,
    this.onToggleOutline,
    this.outlineAvailable = false,
    this.outlineActive = false,
    super.key,
  });

  final Widget navigation;
  final Widget zoom;
  final VoidCallback onToggleSearch;
  final bool searchActive;
  final VoidCallback? onToggleOutline;
  final bool outlineAvailable;
  final bool outlineActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: const Key('reader_control_bar'),
      color: theme.colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              navigation,
              const Spacer(),
              if (outlineAvailable && onToggleOutline != null) ...[
                IconButton(
                  key: const Key('reader_toggle_outline'),
                  tooltip: 'Outline',
                  onPressed: onToggleOutline,
                  icon: Icon(
                    outlineActive ? Icons.bookmark : Icons.bookmark_border,
                  ),
                ),
              ],
              IconButton(
                key: const Key('reader_toggle_search'),
                tooltip: 'Search',
                onPressed: onToggleSearch,
                icon: Icon(
                  searchActive ? Icons.search_off : Icons.search,
                ),
              ),
              zoom,
            ],
          ),
        ),
      ),
    );
  }
}
