import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_expense_tracker/utils/regex_helper.dart';

void main() {
  group('RegexHelper.extractAmount', () {
    test('trích xuất số tiền với định dạng phân cách chấm (150.000 đ)', () {
      const receipt = '''
      SIÊU THỊ COOPMART
      1. Bánh quy: 30.000
      2. Sữa tươi: 120.000
      Tổng cộng: 150.000 đ
      Cảm ơn quý khách
      ''';
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(150000.0));
    });

    test('trích xuất số tiền với định dạng phân cách phẩy (150,000 VND)', () {
      const receipt = '''
      WINMART+
      Total: 150,000 VND
      Ngày: 06/10/2026
      ''';
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(150000.0));
    });

    test('trích xuất số tiền viết tắt dạng k (150k)', () {
      const receipt = '''
      Cà phê Highlands
      Cà phê sữa đá
      Thanh toán: 150k
      ''';
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(150000.0));
    });

    test('trích xuất số tiền lớn hàng triệu (1.250.000 VNĐ)', () {
      const receipt = '''
      NHÀ HÀNG HẢI SẢN
      Tiền mặt: 1.250.000 VNĐ
      ''';
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(1250000.0));
    });

    test('ưu tiên từ khóa TỔNG CỘNG và bỏ qua tiền mặt khách đưa / tiền thối', () {
      const receipt = "TỔNG CỘNG: 35.000 VNĐ\nTiền mặt: 50.000\nTiền thối: 15.000";
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(35000.0));
    });

    test('chuẩn hóa OCR: nhận diện T0NG C0NG khi bị lỗi số 0 và bỏ qua tiền mặt', () {
      const receipt = "T0NG C0NG: 35.000\nTiền mặt: 50.000";
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(35000.0));
    });

    test('toán học heuristic: hóa đơn không từ khóa tìm thấy Max1 == Max2 + X trả về Max2', () {
      const receipt = "Món A 35.000\nTiền mặt 50.000\nThối lại 15.000";
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(35000.0));
    });

    test('fallback: lấy số tiền lớn nhất khi không có từ khóa tổng tiền', () {
      const receipt = "Sườn 65.000\nTôm 65.000\nTIEN MAT 537.000";
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(537000.0));
    });

    test('heuristic: lấy số tiền lớn nhất ở nửa dưới khi không có từ khóa', () {
      const receipt = '''
      Mục 1: 20.000
      Mục 2: 15.000
      50.000
      ''';
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(50000.0));
    });

    test('trích xuất chính xác 537.000 từ hóa đơn Quán Ăn Thiên Tân có số điện thoại DT: 9407863-8259956', () {
      const receipt = '''
      QUAN AN THIEN TAN
      17-19 TON DAN F13Q4 TPHCM
      DT: 9407863-8259956
      *********
      REG 13-11-2011 20:54
      CA 1 MC #01 000887
      BANSO: 47

      1 BUN SING 42,000
      1 MI GION X CHAY 37,000
      2 MI X GION N 80,000
      4 COM BAT BUU 172,000
      1 SUON CHIEN KDO 65,000
      1 HU TIEU N 40,000
      1 TOM LAN BOT 65,000
      2 PEPSI 16,000
      10 TRA DA 20,000
      TIEN MAT
      537,000

      CAM ON QUY KHACH
      HEN GAP LAI!
      ''';
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(537000.0));

      final merchant = RegexHelper.extractMerchantName(receipt);
      expect(merchant, equals('QUAN AN THIEN TAN'));

      final date = RegexHelper.extractDate(receipt);
      expect(date, equals(DateTime(2011, 11, 13, 20, 54)));
    });

    test('trích xuất số tiền khi từ khóa tổng tiền ở dòng trên và số tiền ở dòng kế tiếp', () {
      const receipt = '''
      SIÊU THỊ MINI
      TỔNG CỘNG
      89.000 đ
      ''';
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(89000.0));
    });

    test('bỏ qua dòng tiêu đề cột "Tên món | SL | Đơn giá | Thành tiền" và lấy tổng cộng', () {
      const receipt = '''
      CƠM VĂN PHÒNG
      Tên món | SL | Đơn giá | Thành tiền
      Cơm gà xối mỡ   1   35.000   35.000
      Canh rong biển  1   15.000   15.000
      Tổng cộng 50.000
      ''';
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(50000.0));
    });

    test('hóa đơn có "Thành tiền" ở từng dòng món và "Tổng cộng" trả về đúng tổng', () {
      const receipt = '''
      NHÀ HÀNG HƯƠNG BIỂN
      Món 1: Tôm hấp - Thành tiền: 60.000
      Món 2: Mực nướng - Thành tiền: 90.000
      Tổng cộng: 150.000
      ''';
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(150000.0));
    });

    test('loại trừ sub total, giảm giá, VAT, tiền khách đưa, tiền thối và trả về tổng thanh toán', () {
      const receipt = '''
      SIÊU THỊ TIỆN LỢI
      Sub total: 100.000
      Giảm giá: 20.000
      VAT: 8.000
      Tổng thanh toán: 88.000
      Tiền khách đưa: 100.000
      Tiền thối: 12.000
      ''';
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(88000.0));
    });

    test('loại bỏ các dòng rác chứa SĐT, MST, số bàn không bị bóc tách nhầm làm tổng tiền', () {
      const receipt = '''
      QUÁN ĂN BÌNH DÂN
      DT: 0901234567
      MST: 0312345678
      BÀN SỐ: 12
      Món ăn: 45.000
      ''';
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(45000.0));
    });

    test('trả về null khi văn bản rỗng hoặc không có số', () {
      expect(RegexHelper.extractAmount(''), isNull);
      expect(RegexHelper.extractAmount('Không có thông tin tiền'), isNull);
    });
  });

  group('RegexHelper.extractDate', () {
    test('trích xuất định dạng dd/MM/yyyy có giờ', () {
      const receipt = '''
      CỬA HÀNG TIỆN LỢI
      Ngày mua: 06/10/2026 18:30
      Tổng: 50.000
      ''';
      final date = RegexHelper.extractDate(receipt);
      expect(date, equals(DateTime(2026, 10, 6, 18, 30)));
    });

    test('trích xuất định dạng yyyy-MM-dd', () {
      const receipt = '''
      Store Receipt
      Date: 2026-10-06
      Amount: 100.000
      ''';
      final date = RegexHelper.extractDate(receipt);
      expect(date, equals(DateTime(2026, 10, 6)));
    });

    test('trích xuất định dạng dd-MM-yyyy', () {
      const receipt = '''
      Hóa đơn số: 123
      Ngày: 15-08-2026
      ''';
      final date = RegexHelper.extractDate(receipt);
      expect(date, equals(DateTime(2026, 8, 15)));
    });

    test('trả về null khi ngày không hợp lệ theo tháng (31/02/2026)', () {
      const receipt = 'Hóa đơn ngày 31/02/2026';
      final date = RegexHelper.extractDate(receipt);
      expect(date, isNull);
    });

    test('trả về null khi ngày 31/04/2026 không hợp lệ', () {
      const receipt = 'Hóa đơn ngày 31/04/2026';
      final date = RegexHelper.extractDate(receipt);
      expect(date, isNull);
    });

    test('trích xuất định dạng năm 2 chữ số dd/MM/yy (15/03/26 -> 15/03/2026)', () {
      const receipt = 'Ngày mua: 15/03/26';
      final date = RegexHelper.extractDate(receipt);
      expect(date, equals(DateTime(2026, 3, 15)));
    });

    test('trích xuất ngày kèm theo giờ (REG 15/03/2026 20:54)', () {
      const receipt = 'REG 15/03/2026 20:54';
      final date = RegexHelper.extractDate(receipt);
      expect(date, equals(DateTime(2026, 3, 15, 20, 54)));
    });

    test('trích xuất ngày với giờ ở dòng kế tiếp', () {
      const receipt = '''
      Ngày: 15/03/2026
      Giờ: 20:54
      ''';
      final date = RegexHelper.extractDate(receipt);
      expect(date, equals(DateTime(2026, 3, 15, 20, 54)));
    });

    test('trả về null khi ngày tháng không hợp lệ hoặc không có', () {
      expect(RegexHelper.extractDate(''), isNull);
      expect(RegexHelper.extractDate('Ngày 99/99/2026'), isNull);
      expect(RegexHelper.extractDate('Không có ngày'), isNull);
    });
  });

  group('RegexHelper.extractMerchantName', () {
    test('nhận diện tên cửa hàng có từ khóa Siêu thị / WinMart', () {
      const receipt = '''
      Siêu thị WinMart+
      123 Đường Số 1
      Tổng: 100.000
      ''';
      final merchant = RegexHelper.extractMerchantName(receipt);
      expect(merchant, contains('WinMart'));
    });

    test('nhận diện tên thương hiệu cà phê (Coffee / Highlands)', () {
      const receipt = '''
      Highlands Coffee
      Hóa đơn tính tiền
      Tổng: 55.000
      ''';
      final merchant = RegexHelper.extractMerchantName(receipt);
      expect(merchant, contains('Highlands Coffee'));
    });

    test('nhận diện tên cửa hàng tiện lợi (Circle K)', () {
      const receipt = '''
      Circle K Vietnam
      Hóa đơn GTGT
      06/10/2026
      ''';
      final merchant = RegexHelper.extractMerchantName(receipt);
      expect(merchant, contains('Circle K'));
    });

    test('heuristic: bỏ qua tiêu đề HÓA ĐƠN để lấy tên nhà hàng/cửa hàng', () {
      const receipt = '''
      HÓA ĐƠN THANH TOÁN
      CƠM TẤM BA GHIỀN
      Địa chỉ: Đặng Văn Ngữ
      Tổng tiền: 65.000
      ''';
      final merchant = RegexHelper.extractMerchantName(receipt);
      expect(merchant, equals('CƠM TẤM BA GHIỀN'));
    });

    test('bỏ qua dòng chứa rác URL và lấy tên cửa hàng hợp lệ đầu tiên', () {
      const receipt = "https://google.com?q=bill\nQUAN AN THIEN TAN";
      final merchant = RegexHelper.extractMerchantName(receipt);
      expect(merchant, equals('QUAN AN THIEN TAN'));
    });

    test('trả về null khi văn bản rỗng', () {
      expect(RegexHelper.extractMerchantName(''), isNull);
    });
  });
}
