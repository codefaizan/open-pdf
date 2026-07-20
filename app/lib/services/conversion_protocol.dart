/// Shared constants and validation for the conversion worker protocol.
class ConversionProtocol {
  ConversionProtocol._();

  static const protocolVersion = '1.0';
}

/// Validates an optional page range string (empty means all pages).
bool isValidPageRange(String? pages) {
  if (pages == null || pages.trim().isEmpty) {
    return true;
  }

  final trimmed = pages.trim();
  if (!_pageRangePattern.hasMatch(trimmed)) {
    return false;
  }

  for (final part in trimmed.split(',')) {
    if (part.contains('-')) {
      final bounds = part.split('-');
      if (bounds.length != 2) {
        return false;
      }
      final start = int.tryParse(bounds[0]);
      final end = int.tryParse(bounds[1]);
      if (start == null || end == null || start < 1 || end < 1 || end < start) {
        return false;
      }
    } else {
      final page = int.tryParse(part);
      if (page == null || page < 1) {
        return false;
      }
    }
  }

  return true;
}

final _pageRangePattern = RegExp(r'^\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*$');
