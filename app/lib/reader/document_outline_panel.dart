import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// A simplified outline entry for tests and UI rendering.
abstract class OutlineEntry {
  String get title;
  List<OutlineEntry> get children;
  Object? get destination;
}

class PdfOutlineEntry implements OutlineEntry {
  PdfOutlineEntry(this.node);

  final PdfOutlineNode node;

  @override
  String get title => node.title;

  @override
  List<OutlineEntry> get children =>
      node.children.map(PdfOutlineEntry.new).toList();

  @override
  Object? get destination => node.dest;
}

class DocumentOutlinePanel extends StatelessWidget {
  const DocumentOutlinePanel({
    required this.outline,
    required this.onDestinationSelected,
    super.key,
  });

  final List<OutlineEntry> outline;
  final ValueChanged<Object?> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final entries = _flattenOutline(outline, 0).toList();

    return Material(
      key: const Key('reader_outline_panel'),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: entries.isEmpty
          ? const Center(child: Text('No outline'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.only(
                    left: 12.0 + entry.level * 16.0,
                    right: 12,
                  ),
                  title: Text(entry.entry.title),
                  onTap: () => onDestinationSelected(entry.entry.destination),
                );
              },
            ),
    );
  }

  Iterable<({OutlineEntry entry, int level})> _flattenOutline(
    List<OutlineEntry> nodes,
    int level,
  ) sync* {
    for (final node in nodes) {
      yield (entry: node, level: level);
      yield* _flattenOutline(node.children, level + 1);
    }
  }
}
