import 'package:flutter/material.dart';

class ReaderTabBar extends StatelessWidget {
  const ReaderTabBar({
    required this.titles,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
    super.key,
  });

  final List<String> titles;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: const Key('reader_tab_bar'),
      color: theme.colorScheme.surfaceContainerHighest,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: titles.length,
            itemBuilder: (context, index) {
              final selected = index == activeIndex;
              return _ReaderTab(
                key: Key('reader_tab_$index'),
                title: titles[index],
                selected: selected,
                onSelect: () => onSelect(index),
                onClose: () => onClose(index),
                closeKey: Key('reader_tab_close_$index'),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReaderTab extends StatelessWidget {
  const _ReaderTab({
    required this.title,
    required this.selected,
    required this.onSelect,
    required this.onClose,
    required this.closeKey,
    super.key,
  });

  final String title;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final Key closeKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onSelect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border(
            right: BorderSide(color: theme.dividerColor),
            bottom: BorderSide(
              color: selected ? background : theme.dividerColor,
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              IconButton(
                key: closeKey,
                tooltip: 'Close',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onClose,
                icon: Icon(Icons.close, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
