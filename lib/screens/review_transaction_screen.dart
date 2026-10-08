import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:provider/provider.dart';

import '../controllers/transaction_controller.dart';
import '../models/transaction.dart';
import '../services/ocr_service.dart';
import '../utils/amount_debug_tracer.dart';
import '../utils/regex_helper.dart';
import 'scanner_screen.dart';

class ReviewTransactionScreen extends StatefulWidget {
  const ReviewTransactionScreen({
    super.key,
    this.imagePath,
    this.debugOriginalPath,
  });

  static const routeName = '/review';

  final String? imagePath;
  final String? debugOriginalPath;

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

  String? _rawOcrText;
  AmountDebugTrace? _debugTrace;
  String? _dateWarning;

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
      _dateWarning = null;
    });

    try {
      final ocrResult = await _ocrService.processImage(path);
      final reconstructedRows =
          OcrRowReconstructor.reconstructRows(ocrResult.lines);
      final rawText = reconstructedRows.isNotEmpty
          ? reconstructedRows.join('\n')
          : ocrResult.text;

      final merchant =
          RegexHelper.extractMerchantName(rawText, rows: reconstructedRows);
      final amount =
          RegexHelper.extractAmount(rawText, rows: reconstructedRows);
      final date = RegexHelper.extractDate(rawText, rows: reconstructedRows);
      final trace = AmountDebugTracer.trace(rawText, rows: reconstructedRows);

      if (kDebugMode) {
        debugPrint('===============================================================');
        debugPrint('[DEBUG OCR] THÔNG TIN PHÂN TÍCH OCR & SỐ TIỀN:');
        debugPrint('---------------------------------------------------------------');
        debugPrint('(a) TOÀN BỘ VĂN BẢN OCR THÔ (TỪNG DÒNG CÓ ĐÁNH SỐ DÒNG):');
        final rawLines = rawText.split('\n');
        for (int i = 0; i < rawLines.length; i++) {
          debugPrint('  [Dòng ${(i + 1).toString().padLeft(2, '0')}] ${rawLines[i]}');
        }
        debugPrint('---------------------------------------------------------------');
        debugPrint('(b) ẢNH ĐÃ CROP ĐANG ĐƯỢC ĐƯA VÀO OCR:');
        debugPrint('  - Đường dẫn ảnh sau crop: $path');
        if (widget.debugOriginalPath != null) {
          debugPrint('  - Đường dẫn ảnh gốc trước crop: ${widget.debugOriginalPath}');
        }
        debugPrint('---------------------------------------------------------------');
        debugPrint('(c) BẢNG PHÂN TÍCH TẤT CẢ CÁC DÒNG (KHÔNG BỎ SÓT DÒNG NÀO):');
        for (final line in trace.allLines) {
          final amtStr = line.parsedAmounts.isNotEmpty
              ? line.parsedAmounts.map((a) => '${NumberFormat('#,###').format(a)} đ').join(', ')
              : 'null';
          debugPrint('  [Dòng ${(line.lineNumber).toString().padLeft(2, '0')}] '
              'Text="${line.originalText}" | Norm="${line.normalizedText}" | '
              'Rác=${line.isGarbage ? "CÓ (${line.garbageReason})" : "KHÔNG"} | '
              'Tiền=$amtStr | '
              'LoạiTrừ=${line.isExcluded ? "CÓ (${line.excludedReason})" : "KHÔNG"} | '
              'TrạngThái=${line.status} | LýDo=${line.decisionReason}');
        }
        debugPrint('---------------------------------------------------------------');
        debugPrint('(d) QUY TẮC ĐÃ CHỐT KẾT QUẢ:');
        debugPrint('  - Quy tắc chốt: ${trace.chosenRule}');
        debugPrint('  - Kết quả cuối cùng: ${trace.finalAmount != null ? "${NumberFormat('#,###').format(trace.finalAmount)} đ" : "null"}');
        debugPrint('===============================================================');
      }

      if (mounted) {
        _rawOcrText = rawText;
        _debugTrace = trace;
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
          _dateWarning = null;
        } else {
          _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
          _dateWarning = 'Không đọc được ngày, đang dùng hôm nay - hãy kiểm tra';
        }
      }
    } catch (e) {
      debugPrint('OCR extraction failed: $e');
      if (mounted) {
        _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
        _dateWarning = 'Không đọc được ngày, đang dùng hôm nay - hãy kiểm tra';
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

    final controller = context.read<TransactionController>();

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
        thumbPath: '',
      );

      // 3. Ghi vào repository qua Provider
      await controller.addTransaction(tx);

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

  void _retakePhoto() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, ScannerScreen.routeName);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Chụp lại',
            onPressed: _isSaving ? null : _retakePhoto,
          ),
        ],
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
                      decoration: InputDecoration(
                        labelText: 'Ngày giao dịch (dd/MM/yyyy)',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: const OutlineInputBorder(),
                        enabledBorder: _dateWarning != null
                            ? const OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.orange, width: 2.0),
                              )
                            : null,
                        focusedBorder: _dateWarning != null
                            ? const OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.deepOrange, width: 2.0),
                              )
                            : null,
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
                    if (_dateWarning != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.orange, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _dateWarning!,
                              style: const TextStyle(
                                color: Colors.deepOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                    if (kDebugMode) ...[
                      const SizedBox(height: 16),
                      _buildDebugOcrSection(),
                    ],
                    const SizedBox(height: 24),

                    // 3. Dưới cùng: Nút Chụp lại & Lưu giao dịch
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : _retakePhoto,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Chụp lại'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDebugOcrSection() {
    final rawLines = (_rawOcrText ?? '').split('\n');
    final hasCroppedImage =
        widget.imagePath != null && File(widget.imagePath!).existsSync();
    final hasOriginalImage = widget.debugOriginalPath != null &&
        File(widget.debugOriginalPath!).existsSync();

    return Card(
      color: Colors.amber.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade400, width: 1.5),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.bug_report, color: Colors.deepOrange),
        title: const Text(
          'Debug OCR',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.deepOrange,
          ),
        ),
        subtitle: const Text(
          'Xem OCR thô, ảnh crop, ứng viên số tiền & quy tắc chốt',
          style: TextStyle(fontSize: 12, color: Colors.black87),
        ),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // (a) Toàn bộ văn bản OCR thô, từng dòng có đánh số dòng
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '(a) Toàn bộ văn bản OCR thô (đánh số dòng):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: rawLines.isEmpty ||
                    _rawOcrText == null ||
                    _rawOcrText!.trim().isEmpty
                ? const Text(
                    '(Chưa có văn bản OCR)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < rawLines.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${(i + 1).toString().padLeft(2, '0')}: ${rawLines[i]}',
                            style: const TextStyle(
                              color: Colors.lightGreenAccent,
                              fontSize: 12.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // (b) Ảnh ĐÃ CROP đang được đưa vào OCR
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '(b) Ảnh ĐÃ CROP đang được đưa vào OCR:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Đường dẫn ảnh sau crop:\n${widget.imagePath ?? "Không có"}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          if (hasCroppedImage)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border:
                    Border.all(color: Colors.deepOrange.shade300, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(widget.imagePath!),
                  fit: BoxFit.contain,
                ),
              ),
            )
          else
            const Text(
              '(Không tìm thấy file ảnh crop)',
              style: TextStyle(color: Colors.red),
            ),

          if (hasOriginalImage) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ảnh GỐC trước crop (để so sánh):',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Đường dẫn:\n${widget.debugOriginalPath}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueGrey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.file(
                  File(widget.debugOriginalPath!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // (c) Danh sách phân tích TẤT CẢ CÁC DÒNG (không bỏ dòng nào)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '(c) Phân tích TẤT CẢ CÁC DÒNG (không bỏ dòng nào):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (_debugTrace == null || _debugTrace!.allLines.isEmpty)
            const Text(
              '(Chưa có dữ liệu phân tích dòng)',
              style: TextStyle(fontStyle: FontStyle.italic),
            )
          else
            Column(
              children: _debugTrace!.allLines.map((line) {
                final isChosen = line.status == 'ĐƯỢC CHỌN';
                final isGarbage = line.isGarbage;
                final isExcluded = line.isExcluded;
                final hasAmount = line.parsedAmounts.isNotEmpty;

                Color badgeColor = Colors.grey;
                if (isChosen) {
                  badgeColor = Colors.green;
                } else if (isGarbage || isExcluded) {
                  badgeColor = Colors.red.shade700;
                } else if (hasAmount) {
                  badgeColor = Colors.orange.shade800;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isChosen
                        ? Colors.green.shade50
                        : (isGarbage ? Colors.grey.shade100 : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isChosen
                          ? Colors.green
                          : (hasAmount ? Colors.orange.shade300 : Colors.grey.shade300),
                      width: isChosen ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              line.status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dòng ${line.lineNumber}: "${line.originalText}"',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Chuẩn hóa: "${line.normalizedText}"',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                      Text(
                        '• Rác (_isGarbageLine): ${line.isGarbage ? "CÓ (${line.garbageReason})" : "KHÔNG"}',
                        style: TextStyle(
                          fontSize: 11,
                          color: line.isGarbage ? Colors.red.shade800 : Colors.black87,
                          fontWeight: line.isGarbage ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      Text(
                        '• Tiền parse được: ${line.parsedAmounts.isNotEmpty ? line.parsedAmounts.map((a) => "${NumberFormat('#,###').format(a)} đ").join(", ") : "KHÔNG CÓ"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: line.parsedAmounts.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                          color: line.parsedAmounts.isNotEmpty ? Colors.blue.shade900 : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '• Bị loại trừ (_isExcludedLine): ${line.isExcluded ? "CÓ (${line.excludedReason})" : "KHÔNG"}',
                        style: TextStyle(
                          fontSize: 11,
                          color: line.isExcluded ? Colors.red.shade800 : Colors.black87,
                          fontWeight: line.isExcluded ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (line.decisionReason.isNotEmpty)
                        Text(
                          '• Lý do: ${line.decisionReason}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),

          // (d) Quy tắc đã chốt kết quả
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '(d) Quy tắc đã chốt kết quả:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade400, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.blue, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _debugTrace?.chosenRule ?? 'Chưa xác định quy tắc',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Số tiền cuối cùng: ${_debugTrace?.finalAmount != null ? "${NumberFormat('#,###').format(_debugTrace!.finalAmount)} VNĐ" : "Chưa có"}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
