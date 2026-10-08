import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_expense_tracker/controllers/transaction_controller.dart';
import 'package:ocr_expense_tracker/models/transaction.dart';
import 'package:ocr_expense_tracker/testing/in_memory_transaction_repository.dart';

void main() {
  group('InMemoryTransactionRepository - CRUD & File Deletion Tests', () {
    late InMemoryTransactionRepository repository;

    setUp(() {
      repository = InMemoryTransactionRepository();
    });

    test('save & getAll: lưu thành công và trả về danh sách theo thứ tự ngày giảm dần', () async {
      final tx1 = TransactionModel(
        amount: 50000,
        merchantName: 'Cà phê sáng',
        date: DateTime(2026, 3, 10, 8, 0),
        category: TransactionCategory.food,
      );

      final tx2 = TransactionModel(
        amount: 120000,
        merchantName: 'Sách giáo trình',
        date: DateTime(2026, 3, 12, 10, 0),
        category: TransactionCategory.study,
      );

      await repository.save(tx1);
      await repository.save(tx2);

      final all = await repository.getAll();
      expect(all.length, 2);
      expect(all.first.merchantName, 'Sách giáo trình');
      expect(all.last.merchantName, 'Cà phê sáng');
      expect(all.first.id, greaterThan(0));
    });

    test('update: cập nhật đúng thông tin của giao dịch đã có', () async {
      final tx = TransactionModel(
        amount: 45000,
        merchantName: 'Bánh mì',
        date: DateTime(2026, 3, 15),
        category: TransactionCategory.food,
      );
      await repository.save(tx);

      final allBefore = await repository.getAll();
      final savedId = allBefore.first.id;

      final updatedTx = TransactionModel(
        id: savedId,
        amount: 60000,
        merchantName: 'Bánh mì đặc biệt',
        date: DateTime(2026, 3, 15),
        category: TransactionCategory.food,
      );
      await repository.update(updatedTx);

      final allAfter = await repository.getAll();
      expect(allAfter.length, 1);
      expect(allAfter.first.amount, 60000);
      expect(allAfter.first.merchantName, 'Bánh mì đặc biệt');
    });

    test('delete: xóa giao dịch và xóa cả file ảnh gốc + thumbnail trên ổ đĩa', () async {
      final tempDir = Directory.systemTemp.createTempSync('expense_test_');
      final originalImageFile = File('${tempDir.path}/receipt_original.jpg');
      final thumbImageFile = File('${tempDir.path}/receipt_thumb.jpg');

      await originalImageFile.writeAsString('fake_image_content');
      await thumbImageFile.writeAsString('fake_thumb_content');

      expect(originalImageFile.existsSync(), isTrue);
      expect(thumbImageFile.existsSync(), isTrue);

      final tx = TransactionModel(
        amount: 100000,
        merchantName: 'Siêu thị Co.opmart',
        date: DateTime(2026, 3, 15),
        category: TransactionCategory.food,
        imagePath: originalImageFile.path,
        thumbPath: thumbImageFile.path,
      );
      await repository.save(tx);

      final listBefore = await repository.getAll();
      expect(listBefore.length, 1);

      // Thực hiện xóa
      await repository.delete(tx.id);

      final listAfter = await repository.getAll();
      expect(listAfter.isEmpty, isTrue);

      // Kiểm tra file ảnh gốc và thumbnail đều đã bị xóa
      expect(originalImageFile.existsSync(), isFalse);
      expect(thumbImageFile.existsSync(), isFalse);

      // Thử xóa lại một giao dịch có file đã mất trước đó -> không crash
      final txMissingFile = TransactionModel(
        amount: 20000,
        merchantName: 'Vé gửi xe',
        date: DateTime(2026, 3, 15),
        imagePath: '${tempDir.path}/non_existent_file.jpg',
        thumbPath: '${tempDir.path}/non_existent_thumb.jpg',
      );
      await repository.save(txMissingFile);
      await expectLater(repository.delete(txMissingFile.id), completes);

      // Dọn dẹp thư mục tạm
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('getByCategory: lọc chính xác theo từng danh mục chi tiêu', () async {
      await repository.save(TransactionModel(
        amount: 30000,
        merchantName: 'Trà đá',
        date: DateTime(2026, 3, 1),
        category: TransactionCategory.food,
      ));
      await repository.save(TransactionModel(
        amount: 70000,
        merchantName: 'Ăn trưa',
        date: DateTime(2026, 3, 2),
        category: TransactionCategory.food,
      ));
      await repository.save(TransactionModel(
        amount: 150000,
        merchantName: 'Xăng xe',
        date: DateTime(2026, 3, 3),
        category: TransactionCategory.travel,
      ));

      final foodList = await repository.getByCategory(TransactionCategory.food);
      final travelList = await repository.getByCategory(TransactionCategory.travel);
      final studyList = await repository.getByCategory(TransactionCategory.study);

      expect(foodList.length, 2);
      expect(travelList.length, 1);
      expect(studyList.length, 0);
    });

    test('getByDateRange: lọc chính xác giao dịch trong khoảng thời gian xác định', () async {
      await repository.save(TransactionModel(
        amount: 50000,
        merchantName: 'Đơn 1',
        date: DateTime(2026, 3, 1, 10, 0),
      ));
      await repository.save(TransactionModel(
        amount: 60000,
        merchantName: 'Đơn 2',
        date: DateTime(2026, 3, 5, 12, 0),
      ));
      await repository.save(TransactionModel(
        amount: 70000,
        merchantName: 'Đơn 3',
        date: DateTime(2026, 3, 10, 15, 0),
      ));

      final filtered = await repository.getByDateRange(
        DateTime(2026, 3, 3),
        DateTime(2026, 3, 7),
      );

      expect(filtered.length, 1);
      expect(filtered.first.merchantName, 'Đơn 2');
    });

    test('getTransactionsByWeek: lấy đúng các giao dịch trong tuần chỉ định', () async {
      // Thứ 4, 11/03/2026
      final wednesday = DateTime(2026, 3, 11);
      // Thứ 2 cùng tuần: 09/03/2026
      await repository.save(TransactionModel(
        amount: 40000,
        merchantName: 'Thứ 2',
        date: DateTime(2026, 3, 9, 9, 0),
      ));
      // Chủ nhật cùng tuần: 15/03/2026
      await repository.save(TransactionModel(
        amount: 90000,
        merchantName: 'Chủ nhật',
        date: DateTime(2026, 3, 15, 20, 0),
      ));
      // Tuần trước: 08/03/2026
      await repository.save(TransactionModel(
        amount: 110000,
        merchantName: 'Tuần trước',
        date: DateTime(2026, 3, 8, 20, 0),
      ));

      final weekItems = await repository.getTransactionsByWeek(wednesday);
      expect(weekItems.length, 2);
      expect(weekItems.any((tx) => tx.merchantName == 'Thứ 2'), isTrue);
      expect(weekItems.any((tx) => tx.merchantName == 'Chủ nhật'), isTrue);
      expect(weekItems.any((tx) => tx.merchantName == 'Tuần trước'), isFalse);
    });

    test('getExpensesByCategory: tính đúng tổng tiền phân bổ từng danh mục', () async {
      await repository.save(TransactionModel(
        amount: 50000,
        category: TransactionCategory.food,
        date: DateTime.now(),
      ));
      await repository.save(TransactionModel(
        amount: 30000,
        category: TransactionCategory.food,
        date: DateTime.now(),
      ));
      await repository.save(TransactionModel(
        amount: 120000,
        category: TransactionCategory.gear,
        date: DateTime.now(),
      ));

      final totals = await repository.getExpensesByCategory();
      expect(totals[TransactionCategory.food], 80000);
      expect(totals[TransactionCategory.gear], 120000);
      expect(totals[TransactionCategory.travel], 0);
      expect(totals[TransactionCategory.study], 0);
      expect(totals[TransactionCategory.entertainment], 0);
    });
  });

  group('TransactionController Tests', () {
    late InMemoryTransactionRepository repository;
    late TransactionController controller;

    setUp(() {
      repository = InMemoryTransactionRepository();
      controller = TransactionController(repository: repository);
    });

    test('loadTransactions: cập nhật state và thông báo listener thành công', () async {
      await repository.save(TransactionModel(
        amount: 40000,
        merchantName: 'Cà phê muối',
        date: DateTime.now(),
      ));

      int notifyCount = 0;
      controller.addListener(() {
        notifyCount++;
      });

      await controller.loadTransactions();

      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);
      expect(controller.transactions.length, 1);
      expect(controller.transactions.first.merchantName, 'Cà phê muối');
      expect(notifyCount, greaterThan(0));
    });

    test('Bắt lỗi khởi tạo database: không lưu RAM âm thầm, cập nhật hasError = true', () async {
      repository.shouldThrowOnInit = true;

      await controller.loadTransactions();

      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, contains('Lỗi giả lập khởi tạo cơ sở dữ liệu Isar'));
    });

    test('addTransaction, updateTransaction, deleteTransaction cập nhật controller state', () async {
      final tx = TransactionModel(
        amount: 100000,
        merchantName: 'Nhà sách',
        date: DateTime.now(),
        category: TransactionCategory.study,
      );

      await controller.addTransaction(tx);
      expect(controller.transactions.length, 1);
      expect(controller.transactions.first.merchantName, 'Nhà sách');

      final saved = controller.transactions.first;
      final updated = TransactionModel(
        id: saved.id,
        amount: 120000,
        merchantName: 'Nhà sách Fahasa',
        date: saved.date,
        category: saved.category,
      );

      await controller.updateTransaction(updated);
      expect(controller.transactions.first.amount, 120000);
      expect(controller.transactions.first.merchantName, 'Nhà sách Fahasa');

      await controller.deleteTransaction(saved.id);
      expect(controller.transactions.isEmpty, isTrue);
    });
  });
}
