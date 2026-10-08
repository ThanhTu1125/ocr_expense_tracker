import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_expense_tracker/utils/ocr_row_reconstructor.dart';

void main() {
  group('BƯỚC 2: OcrRowReconstructor Tests', () {
    test('Ghép dòng TIEN MAT và 537000 cùng hàng khi lệch y vài pixel', () {
      final lines = [
        const OcrLine(
          text: 'TIEN MAT',
          boundingBox: Rect.fromLTWH(50, 300, 100, 20),
        ),
        const OcrLine(
          text: '537000',
          boundingBox: Rect.fromLTWH(200, 302, 80, 20),
        ),
      ];

      final rows = OcrRowReconstructor.reconstructRows(lines);
      expect(rows.length, equals(1));
      expect(rows.first, equals('TIEN MAT 537000'));
    });

    test('Ghép các món và giá thành từng hàng đúng thứ tự trái -> phải', () {
      // Giả lập đọc theo cột: danh sách tên món trước, danh sách giá sau
      final lines = [
        // Tên món (cột trái x = 40)
        const OcrLine(text: '1 BUN SING', boundingBox: Rect.fromLTWH(40, 100, 120, 20)),
        const OcrLine(text: '1 MI GION X CHAY', boundingBox: Rect.fromLTWH(40, 130, 140, 20)),
        const OcrLine(text: '2 PEPSI', boundingBox: Rect.fromLTWH(40, 160, 80, 20)),

        // Đơn giá (cột phải x = 220)
        const OcrLine(text: '42,000', boundingBox: Rect.fromLTWH(220, 101, 60, 20)),
        const OcrLine(text: '37,000', boundingBox: Rect.fromLTWH(220, 129, 60, 20)),
        const OcrLine(text: '16,000', boundingBox: Rect.fromLTWH(220, 161, 60, 20)),
      ];

      final rows = OcrRowReconstructor.reconstructRows(lines);
      expect(rows.length, equals(3));
      expect(rows[0], equals('1 BUN SING 42,000'));
      expect(rows[1], equals('1 MI GION X CHAY 37,000'));
      expect(rows[2], equals('2 PEPSI 16,000'));
    });

    test('Chịu được ảnh hơi nghiêng nhẹ (độ chênh lệch y theo chiều cao dòng)', () {
      final lines = [
        const OcrLine(text: 'COM BAT BUU', boundingBox: Rect.fromLTWH(30, 200, 100, 22)),
        const OcrLine(text: '172,000', boundingBox: Rect.fromLTWH(200, 208, 70, 22)),
      ];

      final rows = OcrRowReconstructor.reconstructRows(lines);
      expect(rows.length, equals(1));
      expect(rows.first, equals('COM BAT BUU 172,000'));
    });

    test('Tách thành 2 hàng khác nhau khi khoảng cách y lớn hơn ngưỡng', () {
      final lines = [
        const OcrLine(text: 'Dòng 1', boundingBox: Rect.fromLTWH(30, 100, 100, 20)),
        const OcrLine(text: 'Dòng 2', boundingBox: Rect.fromLTWH(30, 150, 100, 20)),
      ];

      final rows = OcrRowReconstructor.reconstructRows(lines);
      expect(rows.length, equals(2));
      expect(rows[0], equals('Dòng 1'));
      expect(rows[1], equals('Dòng 2'));
    });
  });
}
