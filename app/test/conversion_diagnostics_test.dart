import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/services/conversion_diagnostics.dart';
import 'package:open_pdf/services/conversion_worker_client.dart';

void main() {
  test('diagnostics expose versions only', () {
    const diagnostics = ConversionDiagnostics(
      appVersion: '1.0.0',
      protocolVersion: '1.0',
      workerVersion: '0.1.0',
    );

    expect(
      diagnostics.toMap(),
      {
        'app_version': '1.0.0',
        'protocol_version': '1.0',
        'worker_version': '0.1.0',
      },
    );
    expect(diagnostics.format(), 'app=1.0.0 protocol=1.0 worker=0.1.0');
    expect(diagnostics.format(), isNot(contains('.pdf')));
  });

  test('error messages distinguish recoverable failure classes', () {
    expect(
      conversionErrorMessage(
        ConversionFailure(code: 'CANCELLED', message: 'ignored'),
      ),
      'Conversion was cancelled.',
    );
    expect(
      conversionErrorMessage(
        ConversionFailure(code: 'TIMEOUT', message: 'ignored'),
      ),
      contains('timed out'),
    );
    expect(
      conversionErrorMessage(
        ConversionFailure(code: 'PDF_ENCRYPTED', message: 'ignored'),
      ),
      contains('unsupported encryption'),
    );
    expect(
      conversionErrorMessage(
        ConversionFailure(code: 'DESTINATION_NOT_WRITABLE', message: 'ignored'),
      ),
      contains('Cannot write'),
    );
    expect(
      conversionErrorMessage(
        ConversionFailure(
          code: 'INVALID_REQUEST',
          message: 'Invalid page range: abc.',
        ),
      ),
      'Invalid page range: abc.',
    );
    expect(
      conversionErrorMessage(
        ConversionFailure(code: 'WORKER_CRASHED', message: 'ignored'),
      ),
      contains('stopped unexpectedly'),
    );
  });
}
