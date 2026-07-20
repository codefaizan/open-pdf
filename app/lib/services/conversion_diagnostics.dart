/// Local diagnostics for conversion failures — versions only, no document data.
class ConversionDiagnostics {
  const ConversionDiagnostics({
    required this.appVersion,
    required this.protocolVersion,
    this.workerVersion,
  });

  static const defaultAppVersion = '1.0.0';

  final String appVersion;
  final String protocolVersion;
  final String? workerVersion;

  Map<String, String> toMap() {
    final map = <String, String>{
      'app_version': appVersion,
      'protocol_version': protocolVersion,
    };
    final worker = workerVersion;
    if (worker != null) {
      map['worker_version'] = worker;
    }
    return map;
  }

  String format() {
    final parts = [
      'app=$appVersion',
      'protocol=$protocolVersion',
      if (workerVersion != null) 'worker=$workerVersion',
    ];
    return parts.join(' ');
  }
}

/// Maps structured conversion failure codes to actionable user-facing copy.
String conversionErrorMessage(ConversionFailureLike failure) {
  switch (failure.code) {
    case 'CANCELLED':
      return 'Conversion was cancelled.';
    case 'TIMEOUT':
      return 'Conversion timed out. Try a smaller page range, or try again.';
    case 'PROTOCOL_MISMATCH':
      return 'The converter is incompatible with this app version. '
          'Reinstall the application.';
    case 'MALFORMED_EVENT':
      return 'The converter sent an invalid response. Try again, '
          'or reinstall the application.';
    case 'WORKER_CRASHED':
      return 'The converter stopped unexpectedly. You can try converting again.';
    case 'PDF_UNREADABLE':
      return 'This PDF could not be read. It may be damaged or unsupported.';
    case 'PDF_ENCRYPTED':
      return 'This PDF uses unsupported encryption for conversion. '
          'Use an unprotected copy.';
    case 'DESTINATION_NOT_WRITABLE':
      return 'Cannot write to the chosen location. '
          'Pick a folder you can write to.';
    case 'INVALID_REQUEST':
      return failure.message;
    default:
      return failure.message;
  }
}

/// Minimal surface so message mapping does not depend on the worker client.
abstract interface class ConversionFailureLike {
  String get code;
  String get message;
}
