import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ocr_expense_tracker/main.dart';
import 'package:ocr_expense_tracker/screens/review_transaction_screen.dart';

void main() {
  testWidgets('Test 1: Dashboard displays AppBar title and FloatingActionButton', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
  });

  testWidgets('Test 2: Tapping FloatingActionButton navigates to ScannerScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Scanner'), findsOneWidget);
  });

  testWidgets('Test 3: ReviewTransactionScreen renders correctly with null imagePath', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReviewTransactionScreen(imagePath: null),
      ),
    );

    expect(find.text('Review Transaction'), findsOneWidget);
  });
}
