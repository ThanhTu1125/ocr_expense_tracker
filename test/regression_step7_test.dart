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

    test('7. BƯỚC 7: test/fixtures/ocr_thien_tan_v2.txt -> extractAmount=537000, extractDate=13/11/2011 20:54, tên quán', () {
      final file = File('test/fixtures/ocr_thien_tan_v2.txt');
      expect(file.existsSync(), isTrue);
      final rawText = file.readAsStringSync();

      final amount = RegexHelper.extractAmount(rawText);
      expect(amount, equals(537000.0));

      final merchant = RegexHelper.extractMerchantName(rawText);
      expect(merchant, anyOf(contains('THIEN TAN'), contains('THIẾN TAN')));

      final date = RegexHelper.extractDate(rawText);
      expect(date, isNotNull);
      expect(date!.year, equals(2011));
      expect(date.month, equals(11));
      expect(date.day, equals(13));
      expect(date.hour, equals(20));
      expect(date.minute, equals(54));
    });

    test('8. BƯỚC 3 & 7: Phiên bản 2 hàng riêng ("TIEN MAT" rồi "537.000") vẫn ra 537000 qua lưới an toàn', () {
      const splitCashLines = '''
      QUAN AN THIEN TAN
      1 BUN SING 42, 000
      TIEN MAT
      537.000
      CAM ON QUY KHACH
      ''';

      final amount = RegexHelper.extractAmount(splitCashLines);
      expect(amount, equals(537000.0));
    });

    test('9. BƯỚC 2: Parse số đứng riêng ("537.000", "537,000", "42, 000", "TIEN MAT 537.000") ra đúng, 1.5 và 12.50 giữ thập phân', () {
      expect(RegexHelper.extractAmount('537.000'), equals(537000.0));
      expect(RegexHelper.extractAmount('537,000'), equals(537000.0));
      expect(RegexHelper.extractAmount('42, 000'), equals(42000.0));
      expect(RegexHelper.extractAmount('TIEN MAT 537.000'), equals(537000.0));

      // "1.5" hay "12.50" vẫn là thập phân (không bị biến thành 1500 hay 12500 do phân cách nghìn)
      expect(RegexHelper.extractAmount('1.5'), equals(1.5));
      expect(RegexHelper.extractAmount('12.50'), equals(12.5));
    });

    test('10. BƯỚC 4: Khóa quy tắc ưu tiên - kiểm tra chéo tổng KHÔNG ĐƯỢC ghi đè từ khóa mạnh hoặc tiền mặt', () {
      // Dù có 3 món tạo thành tổng con ngẫu nhiên nhưng có TIEN MAT 537.000 thì vẫn phải chọn 537.000
      const cashReceiptWithSubset = '''
      QUAN AN
      1 MON A 65, 000
      1 MON B 65, 000
      1 MON C 42, 000
      1 MON D 172, 000
      TIEN MAT 537.000
      ''';

      final amount = RegexHelper.extractAmount(cashReceiptWithSubset);
      expect(amount, equals(537000.0)); // Không được chọn 172.000
    });

    test('11. BƯỚC 5: Siết kiểm tra chéo tổng - X phải >= mọi ứng viên và bằng tổng tất cả các món; loại bỏ trùng lặp tập con', () {
      // Hóa đơn 8 món có 1 ứng viên 30.000 trùng tập con 10k+10k+10k nhưng tổng tất cả là 80.000
      const fake8Items = '''
      QUAN AN
      MON 1 10,000
      MON 2 10,000
      MON 3 10,000
      MON 4 10,000
      MON 5 10,000
      MON 6 10,000
      MON 7 10,000
      MON 8 10,000
      GIA TRI CON 30,000
      TONG 80,000
      ''';

      final amount = RegexHelper.extractAmount(fake8Items);
      expect(amount, equals(80000.0)); // Chọn 80.000, không bị chọn nhầm 30.000
    });

    test('12. BƯỚC 6: Sửa chữ nhầm trong số tiền ("16, b00" -> 16000, "65, 00" -> 65000) khi khớp ràng buộc tổng', () {
      expect(RegexHelper.tryFixOcrAmount('2 PEPSI 16, b00'), equals(16000.0));
      expect(RegexHelper.tryFixOcrAmount('1 TOM LAN BOT 65, 00'), equals(65000.0));
    });

    test('13. BƯỚC 5: Dữ liệu dòng 08-16 + 537.000 (không có từ khóa TIEN MAT) -> chọn 537000 qua kiểm tra chéo tổng, không chọn 172000', () {
      const itemsOnlyWithTotal = '''
      1 BUN SING 42, 000
      1 MI GION X CHAY 37,000
      2 MI X GION N 80, 000
      4 COM BAT BUU 172, 000
      1 SUON CHIẾN KDO 65, 000
      1 HU TIEU N 40,000
      1 TOM LAN BOT 65, 00
      2 PEPSI 16, b00
      10 TRA DA 20,000
      537.000
      ''';

      final amount = RegexHelper.extractAmount(itemsOnlyWithTotal);
      expect(amount, equals(537000.0)); // Phải chọn 537000, không được chọn 172000
    });
  });
}
