import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class ThumbnailRail extends StatelessWidget {
  const ThumbnailRail({
    required this.document,
    required this.currentPage,
    required this.onPageSelected,
    super.key,
  });

  final PdfDocument document;
  final int currentPage;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: const Key('reader_thumbnail_rail'),
      color: theme.colorScheme.surfaceContainerLowest,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          itemCount: document.pages.length,
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
            final selected = pageNumber == currentPage;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => onPageSelected(pageNumber),
                borderRadius: BorderRadius.circular(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 140,
                        child: PdfPageView(
                          document: document,
                          pageNumber: pageNumber,
                          maximumDpi: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '$pageNumber',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
