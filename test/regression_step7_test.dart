import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_expense_tracker/utils/regex_helper.dart';

void main() {
  group('BƯỚC 7 - TEST HỒI QUY BẰNG DỮ LIỆU THẬT', () {
    test('1. test/fixtures/ocr_thien_tan.txt -> sau khi chuẩn hóa, extractAmount = 537000', () {
      final file = File('test/fixtures/ocr_thien_tan.txt');
      expect(file.existsSync(), isTrue);
      final rawText = file.readAsStringSync();

      final amount = RegexHelper.extractAmount(rawText);
      expect(amount, equals(537000.0));

      final merchant = RegexHelper.extractMerchantName(rawText);
      expect(merchant, contains('THIẾN TAN'));

      // Ngày có 5 chữ số năm 13-11-20011 -> extractDate phải trả về null
      final date = RegexHelper.extractDate(rawText);
      expect(date, isNull);
    });

    test('2. Hóa đơn Quán Khói: tổng 180000 với cột "T. Tiền" từng món; kiểm tra chéo xác nhận 180000', () {
      const receipt = '''
      QUÁN KHÓI BBQ
      Bàn: 05
      Tên món | SL | ĐG | T. Tiền
      Bò nướng tảng: 120.000
      Nước ngọt: 20.000
      Bia Tiger: 40.000
      T. Tiền: 180.000
      ''';

      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(180000.0));
    });

    test('3. Hóa đơn có dòng tiêu đề cột "Tên món | SL | ĐG | T.Tiền" và "Tổng cộng" -> trả tổng', () {
      const receipt = '''
      NHÀ HÀNG GIA ĐÌNH
      Tên món | SL | ĐG | T.Tiền
      Món xào    1   50.000   50.000
      Món canh   1   40.000   40.000
      Món mặn    1   60.000   60.000
      Tổng cộng: 150.000 đ
      ''';

      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(150000.0));
    });

    test('4. "F1304", "000887", "MC #01 000887", "17-19 TON DAN" không bao giờ thành ứng viên tiền', () {
      const rawNoise = '''
      17-19 TON DAN F1304 TPHCM
      CA 1 MC #01
      000887
      MC #01 000887
      ''';

      final amount = RegexHelper.extractAmount(rawNoise);
      expect(amount, isNull);
    });

    test('5. Chuỗi có dấu cách "42, 000", "172, 000" parse đúng', () {
      const receiptWithSpaces = '''
      QUÁN ĂN
      1 BUN SING 42, 000
      4 COM BAT BUU 172, 000
      TIEN MAT 214, 000
      ''';

      final amount = RegexHelper.extractAmount(receiptWithSpaces);
      expect(amount, equals(214000.0));
    });

    test('6. Kiểm tra chéo Subset Sum tăng độ tin cậy và chọn đúng tổng hóa đơn', () {
      // 3 món 42k + 37k + 80k = 159k
      final items = [42000.0, 37000.0, 80000.0, 20000.0];
      final subset = RegexHelper.findSubsetSum(items, 159000.0);
      expect(subset, isNotNull);
      expect(subset!.length, equals(3));
      expect(subset.reduce((a, b) => a + b), equals(159000.0));
    });
  });
}
