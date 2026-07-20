import 'dart:io';

/// Resolves the conversion worker executable for the current environment.
class WorkerLocator {
  const WorkerLocator({
    this.environment = const String.fromEnvironment('OPEN_PDF_WORKER_EXECUTABLE'),
    this.repoRoot,
  });

  /// Explicit worker path, typically set in tests via environment variable.
  final String environment;

  /// Repository root for development fallbacks.
  final String? repoRoot;

  /// Returns the worker launch command as a direct argument list (never shell).
  /// Returns the resolved worker executable when launching a single binary.
  String? resolvedExecutablePath() {
    if (environment.isNotEmpty) {
      return environment;
    }

    final bundled = _bundledExecutable();
    if (bundled != null) {
      return bundled;
    }

    return _frozenDevelopmentExecutable();
  }

  List<String> resolveLaunchCommand() {
    if (environment.isNotEmpty) {
      return [environment];
    }

    final bundled = _bundledExecutable();
    if (bundled != null) {
      return [bundled];
    }

    final frozen = _frozenDevelopmentExecutable();
    if (frozen != null) {
      return [frozen];
    }

    final dev = _developmentExecutable();
    if (dev != null) {
      return dev;
    }

    throw StateError(
      'Conversion worker not found. Build it with scripts/freeze_worker.sh '
      'or set OPEN_PDF_WORKER_EXECUTABLE.',
    );
  }

  String? workingDirectory() {
    if (environment.isNotEmpty || _bundledExecutable() != null) {
      return null;
    }

    final frozen = _frozenDevelopmentExecutable();
    if (frozen != null) {
      return File(frozen).parent.path;
    }

    final root = _resolvedRepoRoot();
    if (root != null) {
      return '$root/worker';
    }

    return null;
  }

  String? _bundledExecutable() {
    final executable = Platform.resolvedExecutable;
    if (Platform.isMacOS) {
      final bundleRoot = File(executable).parent.parent.parent.path;
      final candidate = '$bundleRoot/Contents/Resources/worker/open_pdf_worker/open_pdf_worker';
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    if (Platform.isWindows) {
      final exeDir = File(executable).parent.path;
      final candidate = '$exeDir\\data\\worker\\open_pdf_worker\\open_pdf_worker.exe';
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return null;
  }

  String? _frozenDevelopmentExecutable() {
    final root = _resolvedRepoRoot();
    if (root == null) {
      return null;
    }

    if (Platform.isWindows) {
      final candidate = '$root/worker/dist/open_pdf_worker/open_pdf_worker.exe';
      return File(candidate).existsSync() ? candidate : null;
    }

    final candidate = '$root/worker/dist/open_pdf_worker/open_pdf_worker';
    return File(candidate).existsSync() ? candidate : null;
  }

  List<String>? _developmentExecutable() {
    final root = _resolvedRepoRoot();
    if (root == null) {
      return null;
    }

    if (Platform.isWindows) {
      final venvPython = '$root/worker/.venv/Scripts/python.exe';
      if (File(venvPython).existsSync()) {
        return [venvPython, '-m', 'open_pdf_worker'];
      }
    } else {
      final venvPython = '$root/worker/.venv/bin/python3';
      if (File(venvPython).existsSync()) {
        return [venvPython, '-m', 'open_pdf_worker'];
      }
    }

    return null;
  }

  String? _resolvedRepoRoot() {
    if (repoRoot != null) {
      return repoRoot;
    }

    var dir = Directory.current;
    for (var depth = 0; depth < 8; depth++) {
      if (File('${dir.path}/tickets.md').existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        break;
      }
      dir = parent;
    }

    return null;
  }
}
