import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_expense_tracker/utils/amount_debug_tracer.dart';
import 'package:ocr_expense_tracker/utils/regex_helper.dart';

void main() {
  group('Chẩn đoán OCR & Parser cho Hóa đơn Quán Ăn Thiên Tân', () {
    test(
        'Kịch bản 1: Hóa đơn Thiên Tân đầy đủ nguyên vẹn (có TIEN MAT và 537.000)',
        () {
      const rawFull = '''
QUAN AN THIEN TAN
17-19 TON DAN F13Q4 TPHCM
DT: 9407863-8259956
********
REG 13-11-2011 20:54
CA 1 MC #01 000887
BANSO : 47
1 BUN SING 42,000
1 MI GION X CHAY 37,000
2 MI X GION N 80,000
4 COM BAT BUU 172,000
3 SUON CHIEN KDO 65,000
1 HU TIEU N 40,000
1 TOM LAN BOT 65,000
2 PEPSI 16,000
10 TRA DA 20,000
TIEN MAT
537.000
CAM ON QUY KHACH
HEN GAP LAI !
''';

      final amount = RegexHelper.extractAmount(rawFull);
      final trace = AmountDebugTracer.trace(rawFull);

      // ignore: avoid_print
      print('=== KỊCH BẢN 1: HÓA ĐƠN ĐẦY ĐỦ ===');
      // ignore: avoid_print
      print('Số tiền trích xuất: $amount');
      // ignore: avoid_print
      print('Quy tắc chốt: ${trace.chosenRule}');
      // ignore: avoid_print
      print('Số lượng ứng viên: ${trace.candidates.length}');
      for (final c in trace.candidates) {
        // ignore: avoid_print
        print(
            '  - Dòng ${c.lineNumber}: "${c.lineText}" -> ${c.amount} (${c.status} | ${c.reason})');
      }

      expect(amount, equals(537000.0));
      expect(trace.chosenRule, contains('537'));
    });

    test(
        'Kịch bản 2: Ảnh sau crop bị cắt ngang ở dòng PEPSI (mất TIEN MAT 537.000)',
        () {
      const rawCroppedAtPepsi = '''
QUAN AN THIEN TAN
17-19 TON DAN F13Q4 TPHCM
DT: 9407863-8259956
********
REG 13-11-2011 20:54
CA 1 MC #01 000887
BANSO : 47
1 BUN SING 42,000
1 MI GION X CHAY 37,000
2 MI X GION N 80,000
4 COM BAT BUU 172,000
3 SUON CHIEN KDO 65,000
1 HU TIEU N 40,000
1 TOM LAN BOT 65,000
2 PEPSI 16,000
''';

      final amount = RegexHelper.extractAmount(rawCroppedAtPepsi);
      final trace = AmountDebugTracer.trace(rawCroppedAtPepsi);

      // ignore: avoid_print
      print('=== KỊCH BẢN 2: CẮT NGANG DÒNG PEPSI (CÒN CÁC DÒNG TRÊN) ===');
      // ignore: avoid_print
      print('Số tiền trích xuất: $amount');
      // ignore: avoid_print
      print('Quy tắc chốt: ${trace.chosenRule}');

      // Khi còn các dòng trên, số lớn nhất là 172.000 (COM BAT BUU)
      expect(amount, equals(172000.0));
    });

    test('Kịch bản 3: Vùng crop chỉ thu được dòng PEPSI 16,000', () {
      const rawOnlyPepsi = '''
QUAN AN THIEN TAN
2 PEPSI 16,000
''';

      final amount = RegexHelper.extractAmount(rawOnlyPepsi);
      final trace = AmountDebugTracer.trace(rawOnlyPepsi);

      // ignore: avoid_print
      print('=== KỊCH BẢN 3: VÙNG CROP CHỈ CÓ SỐ TIỀN CỦA DÒNG PEPSI ===');
      // ignore: avoid_print
      print('Số tiền trích xuất: $amount');
      // ignore: avoid_print
      print('Quy tắc chốt: ${trace.chosenRule}');

      expect(amount, equals(16000.0));
      expect(trace.chosenRule, contains('Fallback số duy nhất'));
    });

    test(
        'Kịch bản 4: Dòng PEPSI hoặc dòng gần đó bị OCR nhận nhầm từ khóa tổng/thanh toán',
        () {
      // Ví dụ ML Kit OCR nhận diện "TIEN MAT 537.000" bị đứt đoạn hoặc nhầm:
      // hoặc dòng PEPSI nhận thành "2 PEPSI TOTAL 16,000"
      const rawPepsiKeyword = '''
QUAN AN THIEN TAN
1 BUN SING 42,000
4 COM BAT BUU 172,000
TOTAL 16,000
''';

      final amount = RegexHelper.extractAmount(rawPepsiKeyword);
      final trace = AmountDebugTracer.trace(rawPepsiKeyword);

      // ignore: avoid_print
      print('=== KỊCH BẢN 4: KHỚP TỪ KHÓA YẾU TOTAL ===');
      // ignore: avoid_print
      print('Số tiền trích xuất: $amount');
      // ignore: avoid_print
      print('Quy tắc chốt: ${trace.chosenRule}');

      expect(amount, equals(16000.0));
      expect(trace.chosenRule, contains('Từ khóa yếu'));
    });
  });
}
