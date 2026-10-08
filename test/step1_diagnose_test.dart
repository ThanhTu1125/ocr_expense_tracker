import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_expense_tracker/utils/amount_debug_tracer.dart';
import 'package:ocr_expense_tracker/utils/regex_helper.dart';

void main() {
  test('BƯỚC 1 - Chẩn đoán trực tiếp hàm parse số tiền', () {
    final testStrings = [
      '537.000',
      '537,000',
      '537000',
      'TIEN MAT 537.000',
      '172, 000',
      '65, 00',
      '16, b00',
    ];

    // ignore: avoid_print
    print('===============================================================');
    // ignore: avoid_print
    print('BƯỚC 1 - KẾT QUẢ CHẨN ĐOÁN CÁC CHUỖI:');
    // ignore: avoid_print
    print('===============================================================');

    for (final s in testStrings) {
      final amount = RegexHelper.extractAmount(s);
      final trace = AmountDebugTracer.trace(s);
      final thousandNormalized = RegexHelper.normalizeThousandSeparators(s);
      final textNormalized = AmountDebugTracer.normalize(s);

      // ignore: avoid_print
      print('Chuỗi gốc: "$s"');
      // ignore: avoid_print
      print('  -> normalizeThousandSeparators: "$thousandNormalized"');
      // ignore: avoid_print
      print('  -> AmountDebugTracer.normalize: "$textNormalized"');
      // ignore: avoid_print
      print('  -> extractAmount: $amount');
      // ignore: avoid_print
      print('  -> Chosen rule: ${trace.chosenRule}');
      if (trace.allLines.isNotEmpty) {
        final line = trace.allLines.first;
        // ignore: avoid_print
        print('  -> Line debug: isGarbage=${line.isGarbage} (${line.garbageReason}) | '
            'parsedAmounts=${line.parsedAmounts} | isExcluded=${line.isExcluded} (${line.excludedReason}) | '
            'status=${line.status} | reason=${line.decisionReason}');
      }
      // ignore: avoid_print
      print('---------------------------------------------------------------');
    }
  });

  test('BƯỚC 1 - Chẩn đoán với văn bản thô Thiên Tân v2', () {
    const rawThienTanV2 = '''
QUAN AN THIẾN TAN
17-19 TON DAN F 1304 TPHCM
OT: 9407863-8259956
**>k***
REG 13-11-2011 20:54
CA 1 MC #01 000887
BANSO:47
1 BUN SING 42, 000
1 MI GION X CHAY 37,000
2 MI X GION N 80, 000
4 COM BAT BUU 172, 000
1 SUON CHIẾN KDO 65, 000
1 HU TIEU N 40,000
1 TOM LAN BOT 65, 00
2 PEPSI 16, b00
10 TRA DA 20,000
TIEN MAT
537.000
CAM ON QUY KHACH
HEN GAP LAII
''';

    final amount = RegexHelper.extractAmount(rawThienTanV2);
    final trace = AmountDebugTracer.trace(rawThienTanV2);

    // ignore: avoid_print
    print('===============================================================');
    // ignore: avoid_print
    print('CHẨN ĐOÁN HÓA ĐƠN THIÊN TÂN V2 NGUYÊN VĂN:');
    // ignore: avoid_print
    print('extractAmount = $amount');
    // ignore: avoid_print
    print('Quy tắc chốt: ${trace.chosenRule}');
    // ignore: avoid_print
    print('BẢNG TẤT CẢ CÁC DÒNG:');
    for (final l in trace.allLines) {
      final amt = l.parsedAmounts.isNotEmpty ? l.parsedAmounts.join(', ') : 'null';
      // ignore: avoid_print
      print('  Dòng ${l.lineNumber.toString().padLeft(2, '0')} | Text: "${l.originalText.padRight(28)}" | Tiền: $amt | Rác: ${l.isGarbage} | Trạng thái: ${l.status} | ${l.decisionReason}');
    }
    // ignore: avoid_print
    print('===============================================================');
  });
}
