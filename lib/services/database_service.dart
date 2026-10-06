import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/transaction.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();

  DatabaseService._internal();

  factory DatabaseService() => instance;

  Isar? _isar;

  Isar get isar {
    if (_isar == null || !_isar!.isOpen) {
      throw StateError(
        'DatabaseService has not been initialized. Call init() first.',
      );
    }
    return _isar!;
  }

  bool get isInitialized => _isar != null && _isar!.isOpen;

  Future<void> init() async {
    if (_isar != null && _isar!.isOpen) return;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [TransactionModelSchema],
      directory: dir.path,
    );
  }

  Future<void> saveTransaction(TransactionModel tx) async {
    if (!isInitialized) {
      await init();
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
    final db = isar;
    return await db.transactionModels.where().sortByDateDesc().findAll();
  }

  /// Lấy danh sách giao dịch trong tuần (mặc định: tuần hiện tại)
  Future<List<TransactionModel>> getTransactionsByWeek([DateTime? dateInWeek]) async {
    if (!isInitialized) {
      await init();
    }
    final db = isar;
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
    );

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
