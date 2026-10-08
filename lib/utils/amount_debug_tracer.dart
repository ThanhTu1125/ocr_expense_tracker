import 'regex_helper.dart';

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
  final List<AmountCandidateTrace> candidates;
  final String chosenRule;
  final double? finalAmount;

  AmountDebugTrace({
    required this.rawText,
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
    'tien mat',
    'tien thoi',
    'thoi lai',
    'so luong',
  ];

  static String _normalize(String text) {
    var result = text.toLowerCase().trim();
    result = result.replaceAll('0', 'o').replaceAll('q', 'o');
    const withAccents =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const withoutAccents =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return result.replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _isExcluded(String norm) {
    for (final kw in _excludedKeywords) {
      if (norm.contains(kw)) return true;
    }
    if (RegExp(r'\bv\.?a\.?t\b').hasMatch(norm)) return true;
    if (RegExp(r'\bthue\b').hasMatch(norm)) return true;
    if (RegExp(r'\bcash\b').hasMatch(norm)) return true;
    if (RegExp(r'\bchange\b').hasMatch(norm)) return true;
    return false;
  }

  static bool _isGarbageLine(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.isEmpty) return true;
    if (RegExp(r'(=|&|\?q=|http|www|\.com)', caseSensitive: false)
        .hasMatch(line)) {
      return true;
    }
    if (RegExp(r'^[\s*\-=_~]{3,}$').hasMatch(line)) return true;
    if (RegExp(
      r'(^(dt|d/t|đ/t|tel|hotline|phone|dien\s*thoai|fax)\b)|'
      r'(\b(dt|d/t|đ/t|tel|hotline|phone|dien\s*thoai|fax)\s*[:.])|'
      r'(\b\d{6,11}\s*[-/]\s*\d{6,11}\b)|'
      r'(^(0\d{9,10}|\d{7,8})$)',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }
    if (RegExp(
      r'\b(mst|ma\s*so\s*thue|tax\s*code|so\s*hd|so\s*bill|so\s*phieu|inv\s*no|stk|tai\s*khoan)\b',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }
    if (RegExp(
      r'(\b(banso|ban\s*so|so\s*ban|table)\s*[:#]?\s*\d+)|'
      r'(\b(mc\s*#|pos\s*#|thu\s*ngan|cashier|nv\s*ban)\b)',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }
    final dateRegex = RegExp(r'\b\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}\b');
    final timeRegex = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b');
    if ((dateRegex.hasMatch(line) || timeRegex.hasMatch(line)) &&
        !RegExp(r'\b(tong|total|tien|amount|vnd|đ|k)\b', caseSensitive: false)
            .hasMatch(line)) {
      return true;
    }
    return false;
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

  /// Phân tích vết chi tiết chuỗi OCR
  static AmountDebugTrace trace(String text) {
    final finalAmount = RegexHelper.extractAmount(text);
    final rawLines = text.split('\n');
    final cleanLines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (text.trim().isEmpty || cleanLines.isEmpty) {
      return AmountDebugTrace(
        rawText: text,
        candidates: [],
        chosenRule: 'Không có dữ liệu văn bản',
        finalAmount: null,
      );
    }

    // 1. Quét từ khóa MẠNH
    double? lastStrongAmount;
    int? lastStrongLineIdx;
    String? lastStrongKeyword;

    for (int i = 0; i < cleanLines.length; i++) {
      final line = cleanLines[i];
      if (_isGarbageLine(line)) continue;
      final norm = _normalize(line);
      if (_isExcluded(norm)) continue;

      final matchedStrong =
          _strongKeywords.where((kw) => norm.contains(kw)).toList();
      if (matchedStrong.isNotEmpty) {
        var lineAmt = RegexHelper.extractAmount(line);
        if (lineAmt == null || lineAmt <= 0) {
          if (i + 1 < cleanLines.length && !_isGarbageLine(cleanLines[i + 1])) {
            final nextNorm = _normalize(cleanLines[i + 1]);
            if (!_isExcluded(nextNorm)) {
              lineAmt = RegexHelper.extractAmount(cleanLines[i + 1]);
            }
          }
        }
        if (lineAmt != null && lineAmt > 0) {
          lastStrongAmount = lineAmt;
          lastStrongLineIdx = i;
          lastStrongKeyword = matchedStrong.first;
        }
      }
    }

    // 2. Quét từ khóa YẾU
    double? lastWeakAmount;
    int? lastWeakLineIdx;
    String? lastWeakKeyword;

    if (lastStrongAmount == null) {
      for (int i = 0; i < cleanLines.length; i++) {
        final line = cleanLines[i];
        if (_isGarbageLine(line)) continue;
        final norm = _normalize(line);
        if (_isExcluded(norm) || _isColumnHeader(norm, line)) continue;

        final matchedWeak =
            _weakKeywords.where((kw) => norm.contains(kw)).toList();
        if (matchedWeak.isNotEmpty) {
          var lineAmt = RegexHelper.extractAmount(line);
          if (lineAmt == null || lineAmt <= 0) {
            if (i + 1 < cleanLines.length &&
                !_isGarbageLine(cleanLines[i + 1])) {
              final nextNorm = _normalize(cleanLines[i + 1]);
              if (!_isExcluded(nextNorm) &&
                  !_isColumnHeader(nextNorm, cleanLines[i + 1])) {
                lineAmt = RegexHelper.extractAmount(cleanLines[i + 1]);
              }
            }
          }
          if (lineAmt != null && lineAmt > 0) {
            lastWeakAmount = lineAmt;
            lastWeakLineIdx = i;
            lastWeakKeyword = matchedWeak.first;
          }
        }
      }
    }

    // 3. Fallback Heuristic
    final fallbackList = <({int lineNum, String lineText, double val})>[];
    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty || _isGarbageLine(line)) continue;
      final val = RegexHelper.extractAmount(line);
      if (val != null && val > 0) {
        fallbackList.add((lineNum: i + 1, lineText: line, val: val));
      }
    }

    String chosenRule = 'Không tìm thấy số tiền hợp lệ';
    int? chosenLineNum;

    if (lastStrongAmount != null) {
      chosenRule =
          'Từ khóa mạnh: "$lastStrongKeyword" (${lastStrongAmount.toStringAsFixed(0)} đ)';
      chosenLineNum = (lastStrongLineIdx ?? 0) + 1;
    } else if (lastWeakAmount != null) {
      chosenRule =
          'Từ khóa yếu: "$lastWeakKeyword" (${lastWeakAmount.toStringAsFixed(0)} đ)';
      chosenLineNum = (lastWeakLineIdx ?? 0) + 1;
    } else if (fallbackList.isNotEmpty) {
      final sorted = List.of(fallbackList)
        ..sort((a, b) => b.val.compareTo(a.val));
      final max1 = sorted[0];

      if (sorted.length >= 2) {
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
              'Fallback Max1 = Max2 + X (Max1: ${max1.val.toStringAsFixed(0)} đ, '
              'Max2: ${max2.val.toStringAsFixed(0)} đ, X: ${matchedX.val.toStringAsFixed(0)} đ -> Chọn Max2)';
          chosenLineNum = max2.lineNum;
        } else {
          chosenRule =
              'Fallback số lớn nhất (Max1: ${max1.val.toStringAsFixed(0)} đ tại dòng ${max1.lineNum})';
          chosenLineNum = max1.lineNum;
        }
      } else {
        chosenRule =
            'Fallback số duy nhất (${max1.val.toStringAsFixed(0)} đ tại dòng ${max1.lineNum})';
        chosenLineNum = max1.lineNum;
      }
    }

    // Xây dựng danh sách ứng viên chi tiết từng dòng
    final candidates = <AmountCandidateTrace>[];
    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      final lineNum = i + 1;
      if (line.isEmpty) continue;

      if (_isGarbageLine(line)) {
        candidates.add(AmountCandidateTrace(
          lineNumber: lineNum,
          lineText: line,
          amount: null,
          status: 'BỊ LOẠI',
          reason: 'Dòng thông tin phụ / rác (ngày giờ, SĐT, header)',
        ));
        continue;
      }

      final norm = _normalize(line);
      final isEx = _isExcluded(norm);
      final amt = RegexHelper.extractAmount(line);

      if (amt == null || amt <= 0) {
        if (isEx) {
          candidates.add(AmountCandidateTrace(
            lineNumber: lineNum,
            lineText: line,
            amount: null,
            status: 'BỊ LOẠI',
            reason: 'Dòng chứa từ khóa loại trừ (tiền mặt / tiền thối / vat)',
          ));
        }
        continue;
      }

      final isChosen = (finalAmount != null &&
          (amt - finalAmount).abs() < 0.01 &&
          (chosenLineNum == null || chosenLineNum == lineNum));

      String reason;
      if (isChosen) {
        reason = 'Được chọn theo quy tắc: $chosenRule';
      } else if (isEx) {
        reason =
            'Bị loại do dòng chứa từ khóa loại trừ (tiền mặt, tiền thối, cash...)';
      } else if (lastStrongAmount != null) {
        reason =
            'Bị loại do ưu tiên từ khóa mạnh "$lastStrongKeyword" tại dòng khác';
      } else if (lastWeakAmount != null) {
        reason =
            'Bị loại do ưu tiên từ khóa yếu "$lastWeakKeyword" tại dòng khác';
      } else {
        reason =
            'Bị loại do quy tắc Fallback Heuristic (nhỏ hơn số được chọn hoặc không thỏa Max1=Max2+X)';
      }

      candidates.add(AmountCandidateTrace(
        lineNumber: lineNum,
        lineText: line,
        amount: amt,
        status: isChosen ? 'ĐƯỢC CHỌN' : 'BỊ LOẠI',
        reason: reason,
      ));
    }

    return AmountDebugTrace(
      rawText: rawLines.join('\n'),
      candidates: candidates,
      chosenRule: chosenRule,
      finalAmount: finalAmount,
    );
  }
}
