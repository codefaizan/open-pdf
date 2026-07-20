import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_pdf/reader/convert_to_excel_dialog.dart';

void main() {
  testWidgets('convert dialog defaults to all pages and validates ranges', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () {
                    showConvertToExcelDialog(context, pageCount: 12);
                  },
                  child: const Text('Convert'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Convert'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('convert_to_excel_dialog')), findsOneWidget);
    expect(find.textContaining('All 12 pages'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('convert_page_range_field')), 'bad-range');
    await tester.tap(find.byKey(const Key('convert_continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('convert_to_excel_dialog')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('convert_page_range_field')), '1-3,5');
    await tester.tap(find.byKey(const Key('convert_continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('convert_to_excel_dialog')), findsNothing);
  });
}
