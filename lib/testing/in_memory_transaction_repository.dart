import 'dart:io';

import 'package:isar_community/isar.dart';

import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Repository lưu trữ trong RAM CHỈ DÙNG CHO TESTING.
/// Không dùng trong production.
class InMemoryTransactionRepository implements TransactionRepository {
  final List<TransactionModel> _items = [];
  int _nextId = 1;

  /// Cờ hỗ trợ test giả lập lỗi khởi tạo Isar / Database
  bool shouldThrowOnInit = false;

  @override
  Future<void> init() async {
    if (shouldThrowOnInit) {
      throw Exception('Lỗi giả lập khởi tạo cơ sở dữ liệu Isar!');
    }
  }

  void clear() {
    _items.clear();
    _nextId = 1;
  }

  @override
  Future<void> save(TransactionModel transaction) async {
    if (transaction.id == Isar.autoIncrement || transaction.id <= 0) {
      transaction.id = _nextId++;
    } else if (transaction.id >= _nextId) {
      _nextId = transaction.id + 1;
    }
    _items.add(transaction);
  }

  @override
  Future<void> update(TransactionModel transaction) async {
    final index = _items.indexWhere((tx) => tx.id == transaction.id);
    if (index != -1) {
      _items[index] = transaction;
    } else {
      throw StateError('Không tìm thấy giao dịch với ID: ${transaction.id}');
    }
  }

  @override
  Future<void> delete(int id) async {
    final index = _items.indexWhere((tx) => tx.id == id);
    if (index != -1) {
      final tx = _items[index];
      await _deleteFileSafely(tx.imagePath);
      await _deleteFileSafely(tx.thumbPath);
      _items.removeAt(index);
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
    final list = List<TransactionModel>.from(_items);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<List<TransactionModel>> getByCategory(TransactionCategory category) async {
    final list = _items.where((tx) => tx.category == category).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<List<TransactionModel>> getByDateRange(DateTime start, DateTime end) async {
    final list = _items.where((tx) {
      return (tx.date.isAfter(start) || tx.date.isAtSameMomentAs(start)) &&
          (tx.date.isBefore(end) || tx.date.isAtSameMomentAs(end));
    }).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
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

    return getByDateRange(startOfWeek, endOfWeek);
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
