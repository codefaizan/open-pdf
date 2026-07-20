import 'package:flutter/material.dart';

class ReaderZoomControls extends StatelessWidget {
  const ReaderZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitWidth,
    required this.onFitPage,
    super.key,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitWidth;
  final VoidCallback onFitPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('reader_zoom_controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('reader_zoom_out'),
          tooltip: 'Zoom out',
          onPressed: onZoomOut,
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          key: const Key('reader_zoom_in'),
          tooltip: 'Zoom in',
          onPressed: onZoomIn,
          icon: const Icon(Icons.add),
        ),
        const SizedBox(width: 4),
        OutlinedButton(
          key: const Key('reader_fit_width'),
          onPressed: onFitWidth,
          child: const Text('Fit width'),
        ),
        const SizedBox(width: 4),
        OutlinedButton(
          key: const Key('reader_fit_page'),
          onPressed: onFitPage,
          child: const Text('Fit page'),
        ),
      ],
    );
  }
}
