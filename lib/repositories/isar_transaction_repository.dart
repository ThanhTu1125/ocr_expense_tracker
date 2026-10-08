import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/transaction.dart';
import 'transaction_repository.dart';

class IsarTransactionRepository implements TransactionRepository {
  Isar? _isar;

  Isar get _db {
    if (_isar == null || !_isar!.isOpen) {
      throw StateError(
        'IsarTransactionRepository chưa được khởi tạo. Hãy gọi init() trước.',
      );
    }
    return _isar!;
  }

  @override
  Future<void> init() async {
    if (_isar != null && _isar!.isOpen) return;

    // Production: Mở Isar trực tiếp, nếu lỗi ném exception để UI hiển thị màn hình lỗi và nút Thử lại
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [TransactionModelSchema],
      directory: dir.path,
    );
  }

  @override
  Future<void> save(TransactionModel transaction) async {
    final db = _db;
    await db.writeTxn(() async {
      await db.transactionModels.put(transaction);
    });
  }

  @override
  Future<void> update(TransactionModel transaction) async {
    final db = _db;
    await db.writeTxn(() async {
      await db.transactionModels.put(transaction);
    });
  }

  @override
  Future<void> delete(int id) async {
    final db = _db;
    final tx = await db.transactionModels.get(id);
    if (tx != null) {
      await _deleteFileSafely(tx.imagePath);
      await _deleteFileSafely(tx.thumbPath);
      await db.writeTxn(() async {
        await db.transactionModels.delete(id);
      });
    }
  }

  Future<void> _deleteFileSafely(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Bọc try/catch, không crash nếu file đã mất hoặc lỗi IO
    }
  }

  @override
  Future<List<TransactionModel>> getAll() async {
    final db = _db;
    return await db.transactionModels.where().sortByDateDesc().findAll();
  }

  @override
  Future<List<TransactionModel>> getByCategory(TransactionCategory category) async {
    final db = _db;
    return await db.transactionModels
        .filter()
        .categoryEqualTo(category)
        .sortByDateDesc()
        .findAll();
  }

  @override
  Future<List<TransactionModel>> getByDateRange(DateTime start, DateTime end) async {
    final db = _db;
    return await db.transactionModels
        .filter()
        .dateBetween(start, end)
        .sortByDateDesc()
        .findAll();
  }

  @override
  Future<List<TransactionModel>> getTransactionsByWeek([DateTime? dateInWeek]) async {
    final reference = dateInWeek ?? DateTime.now();
    final startOfWeek = DateTime(
      reference.year,
      reference.month,
      reference.day - (reference.weekday - 1),
    );
    final endOfWeek = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day + 6,
      23,
      59,
      59,
      999,
    );

    return await getByDateRange(startOfWeek, endOfWeek);
  }

  @override
  Future<Map<TransactionCategory, double>> getExpensesByCategory() async {
    final transactions = await getAll();
    final Map<TransactionCategory, double> totals = {
      for (final cat in TransactionCategory.values) cat: 0.0,
    };

    for (final tx in transactions) {
      totals[tx.category] = (totals[tx.category] ?? 0.0) + tx.amount;
    }

    return totals;
  }
}
