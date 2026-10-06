import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/transaction.dart';

class DatabaseService {
  static DatabaseService instance = DatabaseService._internal();

  DatabaseService._internal();

  factory DatabaseService() => instance;

  Isar? _isar;
  bool useMock = false;
  final List<TransactionModel> mockTransactions = [];

  Isar get isar {
    if (_isar == null || !_isar!.isOpen) {
      throw StateError(
        'DatabaseService has not been initialized. Call init() first.',
      );
    }
    return _isar!;
  }

  bool get isInitialized => useMock || (_isar != null && _isar!.isOpen);

  Future<void> init() async {
    if (useMock) return;
    if (_isar != null && _isar!.isOpen) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        [TransactionModelSchema],
        directory: dir.path,
      );
    } catch (_) {
      useMock = true;
    }
  }

  Future<void> saveTransaction(TransactionModel tx) async {
    if (!isInitialized) {
      await init();
    }
    if (useMock) {
      mockTransactions.insert(0, tx);
      return;
    }
    final db = isar;
    await db.writeTxn(() async {
      await db.transactionModels.put(tx);
    });
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    if (!isInitialized) {
      await init();
    }
    if (useMock) {
      return List.unmodifiable(mockTransactions);
    }
    final db = isar;
    return await db.transactionModels.where().sortByDateDesc().findAll();
  }

  /// Lấy danh sách giao dịch trong tuần (mặc định: tuần hiện tại)
  Future<List<TransactionModel>> getTransactionsByWeek([DateTime? dateInWeek]) async {
    if (!isInitialized) {
      await init();
    }
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
      73,
    );

    if (useMock) {
      return mockTransactions.where((tx) {
        return (tx.date.isAfter(startOfWeek) || tx.date.isAtSameMomentAs(startOfWeek)) &&
            (tx.date.isBefore(endOfWeek) || tx.date.isAtSameMomentAs(endOfWeek));
      }).toList();
    }

    final db = isar;
    return await db.transactionModels
        .filter()
        .dateBetween(startOfWeek, endOfWeek)
        .sortByDateDesc()
        .findAll();
  }

  /// Thống kê tổng số tiền chi tiêu theo từng danh mục
  Future<Map<TransactionCategory, double>> getExpensesByCategory() async {
    final transactions = await getAllTransactions();
    final Map<TransactionCategory, double> totals = {
      for (final cat in TransactionCategory.values) cat: 0.0,
    };

    for (final tx in transactions) {
      totals[tx.category] = (totals[tx.category] ?? 0.0) + tx.amount;
    }

    return totals;
  }
}
