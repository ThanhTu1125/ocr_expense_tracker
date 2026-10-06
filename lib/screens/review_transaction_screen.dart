import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/ocr_service.dart';
import '../utils/regex_helper.dart';

class ReviewTransactionScreen extends StatefulWidget {
  const ReviewTransactionScreen({
    super.key,
    this.imagePath,
  });

  static const routeName = '/review';

  final String? imagePath;

  @override
  State<ReviewTransactionScreen> createState() =>
      _ReviewTransactionScreenState();
}

class _ReviewTransactionScreenState extends State<ReviewTransactionScreen> {
  final _ocrService = OcrService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;

  TransactionCategory _selectedCategory = TransactionCategory.food;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController();
    _amountController = TextEditingController();
    _dateController = TextEditingController();

    if (widget.imagePath != null) {
      _processImage(widget.imagePath!);
    } else {
      _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }
  }

  Future<void> _processImage(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      debugPrint('Image file does not exist: $path');
      _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final rawText = await _ocrService.extractText(path);
      final merchant = RegexHelper.extractMerchantName(rawText);
      final amount = RegexHelper.extractAmount(rawText);
      final date = RegexHelper.extractDate(rawText);

      if (mounted) {
        if (merchant != null) {
          _merchantController.text = merchant;
        }
        if (amount != null) {
          _amountController.text =
              amount.truncateToDouble() == amount
                  ? amount.toInt().toString()
                  : amount.toString();
        }
        _dateController.text =
            date != null
                ? DateFormat('dd/MM/yyyy').format(date)
                : DateFormat('dd/MM/yyyy').format(DateTime.now());
      }
    } catch (e) {
      debugPrint('OCR extraction failed: $e');
      if (mounted) {
        _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi nhận diện OCR: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  DateTime? _parseInputDate(String input) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(input);
    } catch (_) {
      try {
        return DateTime.parse(input);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final amount = double.parse(
        _amountController.text.trim().replaceAll(',', '.'),
      );
      final date =
          _parseInputDate(_dateController.text.trim()) ?? DateTime.now();
      final merchant = _merchantController.text.trim();

      // 1. Copy file ảnh từ cache sang thư mục lưu trữ cố định của app
      String persistentImagePath = '';
      if (widget.imagePath != null && File(widget.imagePath!).existsSync()) {
        final appDir = await getApplicationDocumentsDirectory();
        final ext = widget.imagePath!.split('.').last;
        final newFileName =
            'receipt_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final newPath = '${appDir.path}/$newFileName';
        final savedFile = await File(widget.imagePath!).copy(newPath);
        persistentImagePath = savedFile.path;
      }

      // 2. Tạo đối tượng TransactionModel
      final tx = TransactionModel(
        amount: amount,
        merchantName: merchant,
        date: date,
        category: _selectedCategory,
        imagePath: persistentImagePath,
      );

      // 3. Ghi vào database Isar
      await DatabaseService.instance.saveTransaction(tx);

      // 4. Báo thành công và quay hẳn về Dashboard
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu giao dịch thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      debugPrint('Save transaction failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu giao dịch: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        widget.imagePath != null && File(widget.imagePath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Transaction'),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang xử lý hình ảnh & nhận diện hóa đơn...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Nửa trên: Thumbnail ảnh hóa đơn
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasImage
                          ? Image.file(
                              File(widget.imagePath!),
                              fit: BoxFit.contain,
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 48,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.imagePath != null
                                        ? 'Ảnh hóa đơn: ${widget.imagePath}'
                                        : 'Không có ảnh hóa đơn',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Nửa dưới: Form chỉnh sửa dữ liệu đã bóc tách
                    TextFormField(
                      controller: _merchantController,
                      decoration: const InputDecoration(
                        labelText: 'Tên cửa hàng',
                        prefixIcon: Icon(Icons.storefront),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập tên cửa hàng';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số tiền (VNĐ)',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập số tiền';
                        }
                        final num = double.tryParse(
                          value.trim().replaceAll(',', '.'),
                        );
                        if (num == null || num <= 0) {
                          return 'Số tiền phải là số lớn hơn 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dateController,
                      decoration: const InputDecoration(
                        labelText: 'Ngày giao dịch (dd/MM/yyyy)',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập ngày giao dịch';
                        }
                        final date = _parseInputDate(value.trim());
                        if (date == null) {
                          return 'Định dạng ngày không hợp lệ (dd/MM/yyyy)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Dropdown chọn TransactionCategory
                    DropdownButtonFormField<TransactionCategory>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Danh mục chi tiêu',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: TransactionCategory.values.map((category) {
                        final label = switch (category) {
                          TransactionCategory.food => 'Ăn uống (Food)',
                          TransactionCategory.study => 'Học tập (Study)',
                          TransactionCategory.travel => 'Di chuyển (Travel)',
                          TransactionCategory.gear => 'Thiết bị (Gear)',
                          TransactionCategory.entertainment =>
                            'Giải trí (Entertainment)',
                        };
                        return DropdownMenuItem(
                          value: category,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // 3. Dưới cùng: Nút Lưu giao dịch
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveTransaction,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isSaving ? 'Đang lưu...' : 'Lưu giao dịch',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
