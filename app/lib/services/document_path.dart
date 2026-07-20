import 'dart:io';

/// Returns a user-facing file name from an absolute path.
String documentDisplayName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final separator = normalized.lastIndexOf('/');
  if (separator == -1) {
    return normalized;
  }
  return normalized.substring(separator + 1);
}

/// Validates that [path] refers to a readable PDF file.
Future<String?> validatePdfPath(String path) async {
  final file = File(path);
  // Sync checks so callers (and widget tests) are not blocked on dart:io
  // futures that do not complete under Flutter's fake-async test zone.
  if (!file.existsSync()) {
    return 'The selected file could not be found.';
  }

  try {
    final length = file.lengthSync();
    if (length == 0) {
      return 'This PDF appears to be empty or damaged.';
    }

    final raf = file.openSync();
    try {
      final header = raf.readSync(4);
      if (header.length < 4 || String.fromCharCodes(header) != '%PDF') {
        return 'This file does not appear to be a valid PDF.';
      }
    } finally {
      raf.closeSync();
    }
  } on FileSystemException {
    return 'The selected file could not be read.';
  }

  return null;
}
