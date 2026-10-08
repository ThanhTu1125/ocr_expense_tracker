import 'package:flutter/foundation.dart';

import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';

class TransactionController extends ChangeNotifier {
  final TransactionRepository repository;

  bool _isLoading = false;
  String? _errorMessage;
  List<TransactionModel> _transactions = [];
  List<TransactionModel> _weeklyTransactions = [];
  Map<TransactionCategory, double> _categoryExpenses = {};

  TransactionController({required this.repository});
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  List<TransactionModel> get transactions => _transactions;
  List<TransactionModel> get weeklyTransactions => _weeklyTransactions;
  Map<TransactionCategory, double> get categoryExpenses => _categoryExpenses;

  /// Khởi tạo và tải toàn bộ dữ liệu giao dịch
  Future<void> loadTransactions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await repository.init();
      _transactions = await repository.getAll();
      _weeklyTransactions = await repository.getTransactionsByWeek();
      _categoryExpenses = await repository.getExpensesByCategory();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Thêm giao dịch mới
  Future<void> addTransaction(TransactionModel tx) async {
    _isLoading = true;
    notifyListeners();
    try {
      await repository.save(tx);
      await loadTransactions();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Cập nhật giao dịch
  Future<void> updateTransaction(TransactionModel tx) async {
    _isLoading = true;
    notifyListeners();
    try {
      await repository.update(tx);
      await loadTransactions();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Xóa giao dịch (kèm xóa file ảnh và thumbnail)
  Future<void> deleteTransaction(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await repository.delete(id);
      await loadTransactions();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Lọc giao dịch theo danh mục
  Future<List<TransactionModel>> filterByCategory(TransactionCategory category) async {
    return await repository.getByCategory(category);
  }

  /// Lọc giao dịch theo khoảng thời gian
  Future<List<TransactionModel>> filterByDateRange(DateTime start, DateTime end) async {
    return await repository.getByDateRange(start, end);
  }
}
