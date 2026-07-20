import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_pdf/reader/document_error_view.dart';
import 'package:open_pdf/reader/document_reader_view.dart';
import 'package:open_pdf/reader/empty_reader_view.dart';
import 'package:open_pdf/reader/open_document.dart';
import 'package:open_pdf/reader/reader_shortcuts.dart';
import 'package:open_pdf/reader/reader_tab_bar.dart';
import 'package:open_pdf/services/document_path.dart';
import 'package:open_pdf/services/pdf_open_service.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    this.pdfOpenService = const NativePdfOpenService(),
    this.initialErrorMessage,
    this.initialPdfPath,
    super.key,
  });

  final PdfOpenService pdfOpenService;
  final String? initialErrorMessage;
  final String? initialPdfPath;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _tabs = <OpenDocument>[];
  final _searchHandlers = <String, VoidCallback>{};
  var _activeIndex = 0;
  late String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialErrorMessage;
    final initialPath = widget.initialPdfPath;
    if (initialPath != null && initialPath.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openPath(initialPath));
      });
    }
  }

  Future<void> _openPdf() async {
    final path = await widget.pdfOpenService.pickPdfFile();
    if (!mounted || path == null) {
      return;
    }
    await _openPath(path);
  }

  Future<void> _openPath(String path) async {
    final existing = _tabs.indexWhere((tab) => tab.path == path);
    if (existing != -1) {
      setState(() {
        _activeIndex = existing;
        _errorMessage = null;
      });
      return;
    }

    final validationError = await validatePdfPath(path);
    if (!mounted) {
      return;
    }

    if (validationError != null) {
      if (_tabs.isEmpty) {
        setState(() => _errorMessage = validationError);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError)),
        );
      }
      return;
    }

    var passwordRejected = false;
    setState(() {
      _tabs.add(
        OpenDocument(
          path,
          passwordProvider: () async {
            if (!mounted) {
              return null;
            }
            final password = await promptForPdfPassword(
              context,
              rejected: passwordRejected,
            );
            passwordRejected = true;
            return password;
          },
        ),
      );
      _activeIndex = _tabs.length - 1;
      _errorMessage = null;
    });
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }

    final closedPath = _tabs[index].path;
    setState(() {
      _tabs.removeAt(index);
      _searchHandlers.remove(closedPath);
      if (_tabs.isEmpty) {
        _activeIndex = 0;
      } else if (_activeIndex > index) {
        _activeIndex -= 1;
      } else if (_activeIndex >= _tabs.length) {
        _activeIndex = _tabs.length - 1;
      }
      _errorMessage = null;
    });
  }

  void _closeActiveTab() {
    if (_tabs.isEmpty) {
      return;
    }
    _closeTab(_activeIndex);
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _tabs.length || index == _activeIndex) {
      return;
    }
    setState(() => _activeIndex = index);
  }

  void _registerSearchHandler(String path, VoidCallback handler) {
    _searchHandlers[path] = handler;
  }

  void _runActiveSearch() {
    if (_tabs.isEmpty) {
      return;
    }
    _searchHandlers[_tabs[_activeIndex].path]?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ReaderShortcuts(
      onOpenPdf: _openPdf,
      onSearch: _runActiveSearch,
      onCloseTab: _tabs.isEmpty ? null : _closeActiveTab,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null && _tabs.isEmpty) {
      return DocumentErrorView(
        message: _errorMessage!,
        onOpenPdf: _openPdf,
      );
    }

    if (_tabs.isEmpty) {
      return EmptyReaderView(onOpenPdf: _openPdf);
    }

    return Column(
      children: [
        ReaderTabBar(
          titles: [
            for (final tab in _tabs) documentDisplayName(tab.path),
          ],
          activeIndex: _activeIndex,
          onSelect: _selectTab,
          onClose: _closeTab,
        ),
        Expanded(
          // ponytail: keep all tab viewers alive; unload inactive when memory matters
          child: IndexedStack(
            index: _activeIndex,
            children: [
              for (final tab in _tabs)
                DocumentReaderView(
                  key: ValueKey(tab.path),
                  document: tab,
                  onClose: _closeActiveTab,
                  onOpenPdf: _openPdf,
                  onSearchHandlerReady: (handler) {
                    _registerSearchHandler(tab.path, handler);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
