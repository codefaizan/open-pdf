import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/reader/conversion_progress_panel.dart';
import 'package:open_pdf/services/conversion_worker_client.dart';

void main() {
  testWidgets('progress panel cancel button invokes onCancel', (tester) async {
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversionProgressPanel(
            progress: const ConversionProgress(
              stage: 'extracting',
              percent: 40,
              message: 'Extracting tables',
            ),
            progressEvents: const [
              ConversionProgress(
                stage: 'extracting',
                percent: 40,
                message: 'Extracting tables',
              ),
            ],
            onCancel: () => cancelled = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('conversion_cancel')));
    await tester.pump();

    expect(cancelled, isTrue);
  });
}
