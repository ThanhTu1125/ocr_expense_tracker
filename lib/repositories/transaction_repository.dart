import '../models/transaction.dart';

abstract class TransactionRepository {
  /// Khởi tạo database nếu cần
  Future<void> init();

  /// Lưu mới một giao dịch
  Future<void> save(TransactionModel transaction);

  /// Cập nhật giao dịch đã có
  Future<void> update(TransactionModel transaction);

  /// Xóa giao dịch theo ID (bao gồm cả file ảnh và thumbnail)
  Future<void> delete(int id);

  /// Lấy toàn bộ danh sách giao dịch (sắp xếp mới nhất trước)
  Future<List<TransactionModel>> getAll();

  /// Lọc danh sách giao dịch theo danh mục
  Future<List<TransactionModel>> getByCategory(TransactionCategory category);

  /// Lọc danh sách giao dịch theo khoảng ngày (start <= date <= end)
  Future<List<TransactionModel>> getByDateRange(DateTime start, DateTime end);

  /// Lấy danh sách giao dịch trong tuần (mặc định: tuần hiện tại)
  Future<List<TransactionModel>> getTransactionsByWeek([DateTime? dateInWeek]);

  /// Thống kê tổng số tiền chi tiêu theo từng danh mục
  Future<Map<TransactionCategory, double>> getExpensesByCategory();
}
