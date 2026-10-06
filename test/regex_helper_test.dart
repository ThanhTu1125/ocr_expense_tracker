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

    test('heuristic: lấy số tiền lớn nhất ở nửa dưới khi không có từ khóa', () {
      const receipt = '''
      Mục 1: 20.000
      Mục 2: 30.000
      50.000
      ''';
      final amount = RegexHelper.extractAmount(receipt);
      expect(amount, equals(50000.0));
    });

    test('trả về null khi văn bản rỗng hoặc không có số', () {
      expect(RegexHelper.extractAmount(''), isNull);
      expect(RegexHelper.extractAmount('Không có thông tin tiền'), isNull);
    });
  });

  group('RegexHelper.extractDate', () {
    test('trích xuất định dạng dd/MM/yyyy', () {
      const receipt = '''
      CỬA HÀNG TIỆN LỢI
      Ngày mua: 06/10/2026 18:30
      Tổng: 50.000
      ''';
      final date = RegexHelper.extractDate(receipt);
      expect(date, equals(DateTime(2026, 10, 6)));
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

    test('trả về null khi văn bản rỗng', () {
      expect(RegexHelper.extractMerchantName(''), isNull);
    });
  });
}
