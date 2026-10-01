import 'package:flutter_test/flutter_test.dart';

import 'package:ocr_expense_tracker/main.dart';

void main() {
  testWidgets('App smoke test - shows initial screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('OCR Expense Tracker'), findsOneWidget);
    expect(find.text('Project initialized'), findsOneWidget);
  });
}
