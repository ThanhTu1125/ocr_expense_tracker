import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController();
    _amountController = TextEditingController();
    _dateController = TextEditingController();

    if (widget.imagePath != null) {
      _processImage(widget.imagePath!);
    }
  }

  Future<void> _processImage(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      debugPrint('Image file does not exist: $path');
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
        if (date != null) {
          _dateController.text = DateFormat('dd/MM/yyyy').format(date);
        }
      }
    } catch (e) {
      debugPrint('OCR extraction failed: $e');
      if (mounted) {
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

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.imagePath != null && File(widget.imagePath!).existsSync();

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
                                    style: TextStyle(color: Colors.grey.shade600),
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
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dateController,
                      decoration: const InputDecoration(
                        labelText: 'Ngày giao dịch (dd/MM/yyyy)',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3. Dưới cùng: Nút Lưu giao dịch
                    FilledButton.icon(
                      onPressed: () {
                        // ignore: avoid_print
                        print("Save tapped");
                      },
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'Lưu giao dịch',
                        style: TextStyle(fontSize: 16),
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
