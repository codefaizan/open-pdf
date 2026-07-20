import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReaderShortcuts extends StatelessWidget {
  const ReaderShortcuts({
    required this.onOpenPdf,
    required this.onSearch,
    required this.child,
    super.key,
  });

  final VoidCallback onOpenPdf;
  final VoidCallback onSearch;
  final Widget child;

  static bool get _useControlModifier {
    return Platform.isWindows || Platform.isLinux;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        SingleActivator(
          LogicalKeyboardKey.keyO,
          control: _useControlModifier,
          meta: !_useControlModifier,
        ): const _OpenPdfIntent(),
        SingleActivator(
          LogicalKeyboardKey.keyF,
          control: _useControlModifier,
          meta: !_useControlModifier,
        ): const _SearchIntent(),
      },
      child: Actions(
        actions: {
          _OpenPdfIntent: CallbackAction<_OpenPdfIntent>(
            onInvoke: (_) {
              onOpenPdf();
              return null;
            },
          ),
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              onSearch();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

class _OpenPdfIntent extends Intent {
  const _OpenPdfIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}
