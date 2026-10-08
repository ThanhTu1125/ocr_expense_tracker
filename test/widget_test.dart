import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ocr_expense_tracker/controllers/transaction_controller.dart';
import 'package:ocr_expense_tracker/main.dart';
import 'package:ocr_expense_tracker/models/transaction.dart';
import 'package:ocr_expense_tracker/screens/review_transaction_screen.dart';
import 'package:ocr_expense_tracker/testing/in_memory_transaction_repository.dart';
import 'package:ocr_expense_tracker/widgets/bar_chart_painter.dart';
import 'package:ocr_expense_tracker/widgets/pie_chart_painter.dart';

void main() {
  late InMemoryTransactionRepository repository;
  late TransactionController controller;

  setUp(() {
    repository = InMemoryTransactionRepository();
    controller = TransactionController(repository: repository);
  });

  testWidgets('Test 1: Dashboard displays AppBar title and FloatingActionButton', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
  });

  testWidgets('Test 2: Tapping FloatingActionButton navigates to ScannerScreen', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Scanner'), findsOneWidget);
  });

  testWidgets('Test 3: ReviewTransactionScreen renders correctly with null imagePath and shows Retake button', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionController>.value(
        value: controller,
        child: const MaterialApp(
          home: ReviewTransactionScreen(imagePath: null),
        ),
      ),
    );

    expect(find.text('Review Transaction'), findsOneWidget);
    expect(find.text('Chụp lại'), findsOneWidget);
    expect(find.text('Lưu giao dịch'), findsOneWidget);
  });

  testWidgets('Test 4: Dashboard renders chart cards and empty state gracefully', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Chi tiêu tuần này'), findsOneWidget);
    expect(find.text('Phân bổ theo danh mục'), findsOneWidget);
    expect(find.text('Giao dịch gần đây'), findsOneWidget);
    expect(find.text('Chưa có giao dịch nào'), findsOneWidget);
  });

  testWidgets('Test 5: Dashboard renders transactions when database has items', (WidgetTester tester) async {
    await repository.save(
      TransactionModel(
        amount: 85000,
        merchantName: 'Highlands Coffee',
        date: DateTime.now(),
        category: TransactionCategory.food,
      ),
    );

    await tester.pumpWidget(MyApp(controller: controller));
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

  testWidgets('Test 7: Dashboard hiển thị màn hình lỗi và nút Thử lại khi khởi tạo DB thất bại', (WidgetTester tester) async {
    repository.shouldThrowOnInit = true;

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // Hiển thị màn hình lỗi
    expect(find.text('Lỗi kết nối cơ sở dữ liệu'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);

    // Bấm nút Thử lại sau khi DB đã sẵn sàng
    repository.shouldThrowOnInit = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // Quay lại màn hình Dashboard bình thường
    expect(find.text('Lỗi kết nối cơ sở dữ liệu'), findsNothing);
    expect(find.text('Chi tiêu tuần này'), findsOneWidget);
  });

  testWidgets('Test 8: Tapping Chụp lại on ReviewTransactionScreen pops or navigates back', (WidgetTester tester) async {
    bool returnedToPreviousScreen = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<TransactionController>.value(
        value: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReviewTransactionScreen(imagePath: null),
                      ),
                    );
                    returnedToPreviousScreen = true;
                  },
                  child: const Text('Open Review'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Mở ReviewTransactionScreen
    await tester.tap(find.text('Open Review'));
    await tester.pumpAndSettle();
    expect(find.text('Review Transaction'), findsOneWidget);

    // Bấm nút Chụp lại trên AppBar
    final retakeBtn = find.byTooltip('Chụp lại');
    expect(retakeBtn, findsOneWidget);
    await tester.tap(retakeBtn);
    await tester.pumpAndSettle();

    // Đã quay về màn hình trước
    expect(returnedToPreviousScreen, isTrue);
    expect(find.text('Open Review'), findsOneWidget);
  });
}
