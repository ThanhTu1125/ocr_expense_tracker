import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ocr_expense_tracker/main.dart';
import 'package:ocr_expense_tracker/models/transaction.dart';
import 'package:ocr_expense_tracker/screens/review_transaction_screen.dart';
import 'package:ocr_expense_tracker/services/database_service.dart';
import 'package:ocr_expense_tracker/widgets/bar_chart_painter.dart';
import 'package:ocr_expense_tracker/widgets/pie_chart_painter.dart';

void main() {
  setUp(() {
    DatabaseService.instance.useMock = true;
    DatabaseService.instance.mockTransactions.clear();
  });

  testWidgets('Test 1: Dashboard displays AppBar title and FloatingActionButton', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
  });

  testWidgets('Test 2: Tapping FloatingActionButton navigates to ScannerScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

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

  testWidgets('Test 4: Dashboard renders chart cards and empty state gracefully', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Chi tiêu tuần này'), findsOneWidget);
    expect(find.text('Phân bổ theo danh mục'), findsOneWidget);
    expect(find.text('Giao dịch gần đây'), findsOneWidget);
    expect(find.text('Chưa có giao dịch nào'), findsOneWidget);
  });

  testWidgets('Test 5: Dashboard renders transactions when database has items', (WidgetTester tester) async {
    DatabaseService.instance.mockTransactions.add(
      TransactionModel(
        amount: 85000,
        merchantName: 'Highlands Coffee',
        date: DateTime.now(),
        category: TransactionCategory.food,
      ),
    );

    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Highlands Coffee'), findsOneWidget);
    expect(find.text('Chưa có giao dịch nào'), findsNothing);
  });

  testWidgets('Test 6: CustomPainters render correctly with empty and populated data', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                CustomPaint(
                  size: const Size(200, 200),
                  painter: PieChartPainter(
                    categoryData: {'Ăn uống': 50000.0, 'Học tập': 25000.0},
                    progress: 1.0,
                  ),
                ),
                CustomPaint(
                  size: const Size(200, 200),
                  painter: PieChartPainter(
                    categoryData: {},
                    progress: 1.0,
                  ),
                ),
                CustomPaint(
                  size: const Size(300, 150),
                  painter: BarChartPainter(
                    dailyExpenses: [10000.0, 20000.0, 0.0, 50000.0, 0.0, 0.0, 15000.0],
                    progress: 1.0,
                  ),
                ),
                CustomPaint(
                  size: const Size(300, 150),
                  painter: BarChartPainter(
                    dailyExpenses: [],
                    progress: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
