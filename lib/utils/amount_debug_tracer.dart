import 'package:intl/intl.dart';
import 'regex_helper.dart';

/// Chứa thông tin chi tiết của TỪNG DÒNG văn bản phục vụ chẩn đoán đầy đủ
class LineDebugInfo {
  final int lineNumber;
  final String originalText;
  final String normalizedText;
  final bool isGarbage;
  final String? garbageReason;
  final List<double> parsedAmounts;
  final bool isExcluded;
  final String? excludedReason;
  final String status; // 'ĐƯỢC CHỌN' | 'BỊ LOẠI' | 'KHÔNG CÓ TIỀN'
  final String decisionReason;

  LineDebugInfo({
    required this.lineNumber,
    required this.originalText,
    required this.normalizedText,
    required this.isGarbage,
    this.garbageReason,
    required this.parsedAmounts,
    required this.isExcluded,
    this.excludedReason,
    required this.status,
    required this.decisionReason,
  });
}

/// Đại diện cho một ứng viên số tiền được phân tích
class AmountCandidateTrace {
  final int lineNumber;
  final String lineText;
  final double? amount;
  final String status; // 'ĐƯỢC CHỌN' | 'BỊ LOẠI'
  final String reason;

  AmountCandidateTrace({
    required this.lineNumber,
    required this.lineText,
    this.amount,
    required this.status,
    required this.reason,
  });
}

/// Chứa toàn bộ thông tin trace giải thích thuật toán bóc tách số tiền
class AmountDebugTrace {
  final String rawText;
  final List<LineDebugInfo> allLines;
  final List<AmountCandidateTrace> candidates;
  final String chosenRule;
  final double? finalAmount;

  AmountDebugTrace({
    required this.rawText,
    required this.allLines,
    required this.candidates,
    required this.chosenRule,
    this.finalAmount,
  });
}

/// Tiện ích trace phục vụ chẩn đoán (explainability) thuật toán trích xuất số tiền
class AmountDebugTracer {
  static const List<String> _strongKeywords = [
    'tong cong',
    'tong thanh toan',
    'tien phai tra',
    'phai thanh toan',
    'grand total',
    'total due',
  ];

  static const List<String> _weakKeywords = [
    'thanh tien',
    'tong tien',
    'total',
    'amount',
    'thanh toan',
    'cong tien',
  ];

  static const List<String> _excludedKeywords = [
    'sub total',
    'subtotal',
    'tam tinh',
    'giam gia',
    'discount',
    'khuyen mai',
    'tien khach dua',
    'khach dua',
    'tien thoi',
    'thoi lai',
    'so luong',
  ];

  static String normalize(String text) {
    var result = text.toLowerCase().trim();
    const withAccents =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const withoutAccents =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    result = RegexHelper.normalizeThousandSeparators(result);
    return result.replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _isOnlyAmountLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;

    if (trimmed.startsWith('00') || (trimmed.length > 1 && trimmed.startsWith('0') && !trimmed.startsWith('0.') && !trimmed.startsWith('0,'))) {
      return false;
    }

    final norm = RegexHelper.normalizeThousandSeparators(trimmed);
    final clean = norm.replaceAll(RegExp(r'(vnd|vnđ|đ|k|\$)', caseSensitive: false), '').trim();
    return RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(clean) ||
        (RegExp(r'^\d{4,}$').hasMatch(clean) && (int.tryParse(clean) ?? 0) % 100 == 0);
  }

  static double? _findAmountInNextLines(
    List<String> lines,
    int currentIndex, {
    int maxLookahead = 2,
    bool allowCash = false,
  }) {
    int checkedLines = 0;
    for (int step = 1; (currentIndex + step) < lines.length && checkedLines < maxLookahead; step++) {
      final nextLine = lines[currentIndex + step];
      final trimmed = nextLine.trim();
      if (trimmed.isEmpty) continue;

      if (RegExp(r'^[\s*\-=_~]{3,}$').hasMatch(trimmed)) {
        continue;
      }

      if (checkGarbage(trimmed).isGarbage) {
        checkedLines++;
        break;
      }

      final nextNorm = normalize(trimmed);
      if (checkExcluded(nextNorm, allowCash: allowCash).isExcluded || _isColumnHeader(nextNorm, trimmed)) {
        checkedLines++;
        break;
      }

      checkedLines++;

      if (_isOnlyAmountLine(trimmed)) {
        final amount = RegexHelper.extractAmount(trimmed);
        if (amount != null && amount > 0) {
          return amount;
        }
      } else {
        break;
      }
    }
    return null;
  }

  static ({bool isExcluded, String? reason}) checkExcluded(String norm, {bool allowCash = false}) {
    for (final kw in _excludedKeywords) {
      if (norm.contains(kw)) {
        return (isExcluded: true, reason: 'Chứa từ khóa loại trừ: "$kw"');
      }
    }
    if (!allowCash && norm.contains('tien mat')) {
      return (isExcluded: true, reason: 'Chứa từ khóa loại trừ "tien mat"');
    }
    if (RegExp(r'\bv\.?a\.?t\b').hasMatch(norm)) {
      return (isExcluded: true, reason: 'Chứa từ khóa loại trừ VAT');
    }
    if (RegExp(r'\bthue\b').hasMatch(norm)) {
      return (isExcluded: true, reason: 'Chứa từ khóa loại trừ "thue"');
    }
    if (!allowCash && RegExp(r'\bcash\b').hasMatch(norm)) {
      return (isExcluded: true, reason: 'Chứa từ khóa loại trừ "cash"');
    }
    if (RegExp(r'\bchange\b').hasMatch(norm)) {
      return (isExcluded: true, reason: 'Chứa từ khóa loại trừ "change"');
    }
    return (isExcluded: false, reason: null);
  }

  static ({bool isGarbage, String? reason}) checkGarbage(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.isEmpty) {
      return (isGarbage: true, reason: 'Dòng rỗng');
    }
    if (RegExp(r'(=|&|\?q=|http|www|\.com)', caseSensitive: false).hasMatch(line)) {
      return (isGarbage: true, reason: 'Chứa URL / liên kết web');
    }
    if (RegExp(r'^[\s*\-=_~]{3,}$').hasMatch(line)) {
      return (isGarbage: true, reason: 'Dòng phân cách (***, ---)');
    }
    if (RegExp(
      r'(^(dt|d/t|đ/t|tel|hotline|phone|dien\s*thoai|fax)\b)|'
      r'(\b(dt|d/t|đ/t|tel|hotline|phone|dien\s*thoai|fax)\s*[:.])|'
      r'(\b\d{6,11}\s*[-/]\s*\d{6,11}\b)|'
      r'(^(0\d{9,10}|\d{7,8})$)',
      caseSensitive: false,
    ).hasMatch(line)) {
      return (isGarbage: true, reason: 'Số điện thoại / hotline');
    }
    if (RegExp(
      r'\b(mst|ma\s*so\s*thue|tax\s*code|so\s*hd|so\s*bill|so\s*phieu|inv\s*no|stk|tai\s*khoan)\b',
      caseSensitive: false,
    ).hasMatch(line)) {
      return (isGarbage: true, reason: 'Mã số thuế / Số hóa đơn / STK');
    }
    if (RegExp(
      r'(\b(banso|ban\s*so|so\s*ban|table)\s*[:#]?\s*\d+)|'
      r'(\b(mc\s*#|pos\s*#|thu\s*ngan|cashier|nv\s*ban)\b)',
      caseSensitive: false,
    ).hasMatch(line)) {
      return (isGarbage: true, reason: 'Bàn số / Mã ca POS / Thu ngân');
    }
    final dateRegex = RegExp(r'\b\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}\b');
    final timeRegex = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b');
    if ((dateRegex.hasMatch(line) || timeRegex.hasMatch(line)) &&
        !RegExp(r'\b(tong|total|tien|amount|vnd|đ|k)\b', caseSensitive: false).hasMatch(line)) {
      return (isGarbage: true, reason: 'Ngày giờ không kèm đơn vị tiền');
    }
    return (isGarbage: false, reason: null);
  }

  static bool _isColumnHeader(String normalized, String line) {
    if (!normalized.contains('thanh tien')) return false;
    final hasColumnTerms = normalized.contains('don gia') ||
        normalized.contains('so luong') ||
        normalized.contains('ten mon') ||
        RegExp(r'\b(sl|dg)\b').hasMatch(normalized);
    final amount = RegexHelper.extractAmount(line);
    final hasNoAmount = (amount == null || amount <= 0);
    return hasColumnTerms || hasNoAmount;
  }

  /// Phân tích vết chi tiết chuỗi OCR cho TẤT CẢ các dòng
  static AmountDebugTrace trace(String text, {List<String>? rows}) {
    final finalAmount = RegexHelper.extractAmount(text, rows: rows);
    final rawLines = (rows != null && rows.isNotEmpty)
        ? rows
        : text.split('\n');
    final cleanLines = rawLines
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (rawLines.isEmpty || cleanLines.isEmpty) {
      return AmountDebugTrace(
        rawText: text,
        allLines: [],
        candidates: [],
        chosenRule: 'Không có dữ liệu văn bản',
        finalAmount: null,
      );
    }

    // 1. Quét từ khóa MẠNH (Lưới an toàn tối đa 2 dòng kế tiếp)
    double? lastStrongAmount;
    int? lastStrongLineIdx;
    String? lastStrongKeyword;

    for (int i = 0; i < cleanLines.length; i++) {
      final line = cleanLines[i];
      if (checkGarbage(line).isGarbage) continue;
      final norm = normalize(line);
      if (checkExcluded(norm, allowCash: false).isExcluded) continue;

      final matchedStrong =
          _strongKeywords.where((kw) => norm.contains(kw)).toList();
      if (matchedStrong.isNotEmpty) {
        var lineAmt = RegexHelper.extractAmount(line);
        if (lineAmt == null || lineAmt <= 0) {
          lineAmt = _findAmountInNextLines(cleanLines, i, maxLookahead: 2, allowCash: false);
        }
        if (lineAmt != null && lineAmt > 0) {
          lastStrongAmount = lineAmt;
          lastStrongLineIdx = i;
          lastStrongKeyword = matchedStrong.first;
        }
      }
    }

    // 2. BƯỚC 4: Nếu KHÔNG có từ khóa mạnh, kiểm tra dòng tiền mặt / thanh toán (Lưới an toàn tối đa 2 dòng)
    double? lastCashAmount;
    int? lastCashLineIdx;
    bool hasChangeKeyword = false;

    for (int i = 0; i < cleanLines.length; i++) {
      final line = cleanLines[i];
      if (checkGarbage(line).isGarbage) continue;
      final norm = normalize(line);
      if (norm.contains('tien thoi') || norm.contains('thoi lai')) {
        hasChangeKeyword = true;
      }

      final hasCash = norm.contains('tien mat') ||
          RegExp(r'\bcash\b').hasMatch(norm) ||
          norm.contains('thanh toan');
      if (hasCash) {
        var lineAmt = RegexHelper.extractAmount(line);
        if (lineAmt == null || lineAmt <= 0) {
          lineAmt = _findAmountInNextLines(cleanLines, i, maxLookahead: 2, allowCash: true);
        }
        if (lineAmt != null && lineAmt > 0) {
          lastCashAmount = lineAmt;
          lastCashLineIdx = i;
        }
      }
    }

    // 3. Quét từ khóa YẾU
    double? lastWeakAmount;
    int? lastWeakLineIdx;
    String? lastWeakKeyword;

    for (int i = 0; i < cleanLines.length; i++) {
      final line = cleanLines[i];
      if (checkGarbage(line).isGarbage) continue;
      final norm = normalize(line);
      if (checkExcluded(norm, allowCash: false).isExcluded || _isColumnHeader(norm, line)) continue;

      final matchedWeak =
          _weakKeywords.where((kw) => norm.contains(kw)).toList();
      if (matchedWeak.isNotEmpty) {
        var lineAmt = RegexHelper.extractAmount(line);
        if (lineAmt == null || lineAmt <= 0) {
          lineAmt = _findAmountInNextLines(cleanLines, i, maxLookahead: 2, allowCash: false);
        }
        if (lineAmt != null && lineAmt > 0) {
          lastWeakAmount = lineAmt;
          lastWeakLineIdx = i;
          lastWeakKeyword = matchedWeak.first;
        }
      }
    }

    // 4. Thu thập toàn bộ ứng viên số tiền hợp lệ
    final fallbackList = <({int lineNum, String lineText, double val})>[];
    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty || checkGarbage(line).isGarbage) continue;
      final val = RegexHelper.extractAmount(line);
      if (val != null && val > 0) {
        fallbackList.add((lineNum: i + 1, lineText: line, val: val));
      }
    }

    final allVals = fallbackList.map((e) => e.val).toList();

    String chosenRule = 'Không tìm thấy số tiền hợp lệ';
    int? chosenLineNum;

    // BƯỚC 4: THỨ TỰ CHỐT TỔNG:
    // (1) Từ khóa mạnh
    // (2) Hàng "tiền mặt"/"thanh toán" có số khi KHÔNG có từ khóa mạnh (và không có tiền thối)
    // (3) Kiểm tra chéo tổng (BƯỚC 5)
    // (4) Max1 = Max2 + X
    // (5) Từ khóa yếu / Số lớn nhất
    if (lastStrongAmount != null) {
      chosenRule =
          'Từ khóa mạnh: "$lastStrongKeyword" (${NumberFormat('#,###').format(lastStrongAmount)} đ)';
      chosenLineNum = (lastStrongLineIdx ?? 0) + 1;
    } else if (lastCashAmount != null && !hasChangeKeyword) {
      chosenRule =
          'Từ khóa dòng tiền mặt/thanh toán: (${NumberFormat('#,###').format(lastCashAmount)} đ)';
      chosenLineNum = (lastCashLineIdx ?? 0) + 1;
    } else {
      // (3) Kiểm tra chéo tổng
      final crossCheck = RegexHelper.crossCheckTotal(cleanLines, allVals);
      if (crossCheck != null) {
        chosenRule = crossCheck.description;
        final matched = fallbackList.where((e) => (e.val - crossCheck.totalAmount).abs() < 1.0);
        if (matched.isNotEmpty) {
          chosenLineNum = matched.first.lineNum;
        }
      } else if (hasChangeKeyword && fallbackList.length >= 2) {
        // (4) Heuristic Max1 = Max2 + X
        final sorted = List.of(fallbackList)
          ..sort((a, b) => b.val.compareTo(a.val));
        final max1 = sorted[0];
        final max2 = sorted[1];
        ({int lineNum, String lineText, double val})? matchedX;

        if (max1.val > max2.val) {
          for (int i = 2; i < sorted.length; i++) {
            final x = sorted[i];
            if ((max1.val - (max2.val + x.val)).abs() < 1.0) {
              matchedX = x;
              break;
            }
          }
        }

        if (matchedX != null) {
          chosenRule =
              'Fallback Max1 = Max2 + X (Max1: ${NumberFormat('#,###').format(max1.val)} đ, '
              'Max2: ${NumberFormat('#,###').format(max2.val)} đ, X: ${NumberFormat('#,###').format(matchedX.val)} đ -> Chọn Max2)';
          chosenLineNum = max2.lineNum;
        } else {
          chosenRule =
              'Fallback số lớn nhất (Max1: ${NumberFormat('#,###').format(max1.val)} đ tại dòng ${max1.lineNum})';
          chosenLineNum = max1.lineNum;
        }
      } else if (lastWeakAmount != null) {
        // (5) Từ khóa yếu
        chosenRule =
            'Từ khóa yếu: "$lastWeakKeyword" (${NumberFormat('#,###').format(lastWeakAmount)} đ)';
        chosenLineNum = (lastWeakLineIdx ?? 0) + 1;
      } else if (fallbackList.isNotEmpty) {
        final sorted = List.of(fallbackList)
          ..sort((a, b) => b.val.compareTo(a.val));
        final max1 = sorted[0];
        if (sorted.length == 1) {
          chosenRule =
              'Fallback số duy nhất (${NumberFormat('#,###').format(max1.val)} đ tại dòng ${max1.lineNum})';
        } else {
          chosenRule =
              'Fallback số lớn nhất (Max1: ${NumberFormat('#,###').format(max1.val)} đ tại dòng ${max1.lineNum})';
        }
        chosenLineNum = max1.lineNum;
      }
    }

    // Xây dựng danh sách chi tiết cho TẤT CẢ các dòng
    final allLines = <LineDebugInfo>[];
    final candidates = <AmountCandidateTrace>[];

    for (int i = 0; i < rawLines.length; i++) {
      final lineNum = i + 1;
      final original = rawLines[i];
      final lineTrimmed = original.trim();
      final norm = normalize(original);
      final gCheck = checkGarbage(lineTrimmed);
      final exCheck = checkExcluded(norm, allowCash: lastStrongAmount == null);

      final amt = RegexHelper.extractAmount(lineTrimmed);
      final parsedList = amt != null ? [amt] : <double>[];

      String status = 'KHÔNG CÓ TIỀN';
      String reason = '';

      if (gCheck.isGarbage) {
        status = 'BỊ LOẠI';
        reason = 'Bị loại do là dòng rác: ${gCheck.reason}';
      } else if (exCheck.isExcluded) {
        status = 'BỊ LOẠI';
        reason = 'Bị loại do từ khóa: ${exCheck.reason}';
      } else if (parsedList.isEmpty) {
        status = 'KHÔNG CÓ TIỀN';
        reason = 'Không tìm thấy số tiền hợp lệ trên dòng này';
      } else {
        final isChosen = (finalAmount != null &&
            (amt! - finalAmount).abs() < 0.01 &&
            (chosenLineNum == null || chosenLineNum == lineNum));

        if (isChosen) {
          status = 'ĐƯỢC CHỌN';
          reason = 'Được chọn theo quy tắc: $chosenRule';
        } else if (lastStrongAmount != null) {
          status = 'BỊ LOẠI';
          reason = 'Ưu tiên từ khóa mạnh "$lastStrongKeyword" tại dòng khác';
        } else if (lastCashAmount != null && (amt! - lastCashAmount).abs() > 1.0 && lastStrongAmount == null) {
          status = 'BỊ LOẠI';
          reason = 'Ưu tiên dòng tiền mặt tại dòng khác';
        } else {
          status = 'BỊ LOẠI';
          reason = 'Bị loại do quy tắc chốt ưu tiên ứng viên khác';
        }

        candidates.add(AmountCandidateTrace(
          lineNumber: lineNum,
          lineText: lineTrimmed,
          amount: amt,
          status: isChosen ? 'ĐƯỢC CHỌN' : 'BỊ LOẠI',
          reason: reason,
        ));
      }

      allLines.add(LineDebugInfo(
        lineNumber: lineNum,
        originalText: original,
        normalizedText: norm,
        isGarbage: gCheck.isGarbage,
        garbageReason: gCheck.reason,
        parsedAmounts: parsedList,
        isExcluded: exCheck.isExcluded,
        excludedReason: exCheck.reason,
        status: status,
        decisionReason: reason,
      ));
    }

    return AmountDebugTrace(
      rawText: rawLines.join('\n'),
      allLines: allLines,
      candidates: candidates,
      chosenRule: chosenRule,
      finalAmount: finalAmount,
    );
  }
}
