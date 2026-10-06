import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/database_service.dart';
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
  bool _isLoading = false;
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _weeklyTransactions = [];
  Map<TransactionCategory, double> _categoryExpenses = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseService.instance;
      final all = await db.getAllTransactions();
      final week = await db.getTransactionsByWeek();
      final byCat = await db.getExpensesByCategory();

      if (mounted) {
        setState(() {
          _allTransactions = all;
          _weeklyTransactions = week;
          _categoryExpenses = byCat;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('DashboardScreen _loadData warning (expected in test): $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<double> _computeDailyExpenses() {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );

    final daily = List<double>.filled(7, 0.0);
    for (final tx in _weeklyTransactions) {
      final diff = DateTime(tx.date.year, tx.date.month, tx.date.day)
          .difference(startOfWeek)
          .inDays;
      if (diff >= 0 && diff < 7) {
        daily[diff] += tx.amount;
      }
    }
    return daily;
  }

  Map<String, double> _computeCategoryMap() {
    final Map<String, double> map = {};
    for (final entry in _categoryExpenses.entries) {
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

  @override
  Widget build(BuildContext context) {
    final dailyExpenses = _computeDailyExpenses();
    final categoryMap = _computeCategoryMap();
    final totalWeekly = _weeklyTransactions.fold<double>(
      0.0,
      (sum, tx) => sum + tx.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading) ...[
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
                                final amount = _categoryExpenses[cat] ?? 0.0;
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

              if (_allTransactions.isEmpty)
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
                  itemCount: _allTransactions.length,
                  itemBuilder: (context, index) {
                    final tx = _allTransactions[index];
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
                        trailing: Text(
                          '-${_formatCurrency(tx.amount)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                            fontSize: 14,
                          ),
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
          _loadData();
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
