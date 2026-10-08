import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/transaction_controller.dart';
import '../models/transaction.dart';
import '../widgets/bar_chart_painter.dart';
import '../widgets/pie_chart_painter.dart';
import 'scanner_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const routeName = '/';

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionController>().loadTransactions();
    });
  }

  List<double> _computeDailyExpenses(List<TransactionModel> weeklyTransactions) {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );

    final daily = List<double>.filled(7, 0.0);
    for (final tx in weeklyTransactions) {
      final diff = DateTime(tx.date.year, tx.date.month, tx.date.day)
          .difference(startOfWeek)
          .inDays;
      if (diff >= 0 && diff < 7) {
        daily[diff] += tx.amount;
      }
    }
    return daily;
  }

  Map<String, double> _computeCategoryMap(
    Map<TransactionCategory, double> categoryExpenses,
  ) {
    final Map<String, double> map = {};
    for (final entry in categoryExpenses.entries) {
      map[_getCategoryDisplayName(entry.key)] = entry.value;
    }
    return map;
  }

  String _getCategoryDisplayName(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.food:
        return 'Ăn uống';
      case TransactionCategory.study:
        return 'Học tập';
      case TransactionCategory.travel:
        return 'Di chuyển';
      case TransactionCategory.gear:
        return 'Thiết bị';
      case TransactionCategory.entertainment:
        return 'Giải trí';
    }
  }

  IconData _getCategoryIcon(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.food:
        return Icons.restaurant;
      case TransactionCategory.study:
        return Icons.menu_book;
      case TransactionCategory.travel:
        return Icons.directions_car;
      case TransactionCategory.gear:
        return Icons.devices;
      case TransactionCategory.entertainment:
        return Icons.movie;
    }
  }

  Color _getCategoryColor(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.food:
        return const Color(0xFFFF7043);
      case TransactionCategory.study:
        return const Color(0xFF42A5F5);
      case TransactionCategory.travel:
        return const Color(0xFF26A69A);
      case TransactionCategory.gear:
        return const Color(0xFFAB47BC);
      case TransactionCategory.entertainment:
        return const Color(0xFFEC407A);
    }
  }

  String _formatCurrency(double amount) {
    final intVal = amount.round();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()} ₫';
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  Future<void> _confirmDelete(TransactionModel tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa giao dịch "${tx.merchantName.isNotEmpty ? tx.merchantName : 'Hóa đơn'}" này không? File ảnh hóa đơn sẽ bị xóa theo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final controller = context.read<TransactionController>();
      final messenger = ScaffoldMessenger.of(context);
      try {
        await controller.deleteTransaction(tx.id);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Đã xóa giao dịch thành công.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa giao dịch: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TransactionController>();

    // Màn hình lỗi khi khởi tạo Isar / Database gặp sự cố (Yêu cầu 2.2)
    if (controller.hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Lỗi kết nối cơ sở dữ liệu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage ?? 'Đã xảy ra lỗi không xác định',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    controller.loadTransactions();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dailyExpenses = _computeDailyExpenses(controller.weeklyTransactions);
    final categoryMap = _computeCategoryMap(controller.categoryExpenses);
    final totalWeekly = controller.weeklyTransactions.fold<double>(
      0.0,
      (sum, tx) => sum + tx.amount,
    );
    final allTransactions = controller.transactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () {
              context.read<TransactionController>().loadTransactions();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            context.read<TransactionController>().loadTransactions(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller.isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],

              // Card 1: Biểu đồ cột chi tiêu 7 ngày
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Chi tiêu tuần này',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatCurrency(totalWeekly),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return CustomPaint(
                              size: const Size(double.infinity, 160),
                              painter: BarChartPainter(
                                dailyExpenses: dailyExpenses,
                                progress: value,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card 2: Biểu đồ tròn phân bổ danh mục
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phân bổ theo danh mục',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return CustomPaint(
                                  size: const Size(140, 140),
                                  painter: PieChartPainter(
                                    categoryData: categoryMap,
                                    progress: value,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: TransactionCategory.values.map((cat) {
                                final name = _getCategoryDisplayName(cat);
                                final amount = controller.categoryExpenses[cat] ?? 0.0;
                                final color = _getCategoryColor(cat);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(amount),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Phần Recent Transactions
              const Text(
                'Giao dịch gần đây',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              if (allTransactions.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chưa có giao dịch nào',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allTransactions.length,
                  itemBuilder: (context, index) {
                    final tx = allTransactions[index];
                    final cat = tx.category;
                    final catColor = _getCategoryColor(cat);
                    final catIcon = _getCategoryIcon(cat);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: catColor.withAlpha(40),
                          child: Icon(catIcon, color: catColor),
                        ),
                        title: Text(
                          tx.merchantName.isNotEmpty
                              ? tx.merchantName
                              : 'Hóa đơn chưa đặt tên',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${_formatDate(tx.date)} • ${_getCategoryDisplayName(cat)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '-${_formatCurrency(tx.amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                                fontSize: 14,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.grey,
                                size: 20,
                              ),
                              tooltip: 'Xóa',
                              onPressed: () => _confirmDelete(tx),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, ScannerScreen.routeName);
          if (context.mounted) {
            context.read<TransactionController>().loadTransactions();
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
