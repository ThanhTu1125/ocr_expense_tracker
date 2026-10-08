/// Kết quả kiểm tra chéo tổng các món hàng
class CrossCheckResult {
  final double totalAmount;
  final List<double> itemAmounts;
  final List<int> suspiciousLineNumbers;
  final double? inferredDiff;
  final bool isExact;
  final String description;

  const CrossCheckResult({
    required this.totalAmount,
    required this.itemAmounts,
    required this.suspiciousLineNumbers,
    this.inferredDiff,
    required this.isExact,
    required this.description,
  });
}

class RegexHelper {
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

  static bool _isExcludedLine(String normalized, {bool allowCash = false}) {
    for (final kw in _excludedKeywords) {
      if (normalized.contains(kw)) return true;
    }
    if (!allowCash && normalized.contains('tien mat')) return true;
    if (RegExp(r'\bv\.?a\.?t\b').hasMatch(normalized)) return true;
    if (RegExp(r'\bthue\b').hasMatch(normalized)) return true;
    if (!allowCash && RegExp(r'\bcash\b').hasMatch(normalized)) return true;
    if (RegExp(r'\bchange\b').hasMatch(normalized)) return true;
    return false;
  }

  static bool _isColumnHeader(String normalized, String line) {
    if (!normalized.contains('thanh tien')) return false;

    final hasColumnTerms = normalized.contains('don gia') ||
        normalized.contains('so luong') ||
        normalized.contains('ten mon') ||
        RegExp(r'\b(sl|dg)\b').hasMatch(normalized);

    final amount = _findLargestAmountInLine(line);
    final hasNoAmount = (amount == null || amount <= 0);

    return hasColumnTerms || hasNoAmount;
  }

  /// Chuẩn hóa văn bản: loại bỏ toàn bộ dấu tiếng Việt và sửa lỗi OCR phổ biến (0 -> o, q -> o)
  static String _normalizeText(String input) {
    var result = input.toLowerCase();

    // Thay thế các lỗi OCR phổ biến: số 0 -> chữ o, q -> o
    result = result.replaceAll('0', 'o').replaceAll('q', 'o');

    // Loại bỏ toàn bộ dấu tiếng Việt
    const vietnameseMap = {
      'a': 'áàảãạăắằẳẵặâấầẩẫậ',
      'e': 'éèẻẽẹêếềểễệ',
      'i': 'íìỉĩị',
      'o': 'óòỏõọôốồổỗộơớờởỡợ',
      'u': 'úùủũụưứừửữự',
      'y': 'ýỳỷỹỵ',
      'd': 'đ',
    };

    vietnameseMap.forEach((nonAccent, accents) {
      for (int i = 0; i < accents.length; i++) {
        result = result.replaceAll(accents[i], nonAccent);
      }
    });

    // Chuẩn hóa khoảng trắng
    result = result.replaceAll(RegExp(r'\s+'), ' ');

    return result;
  }

  /// Chuẩn hóa gộp khoảng trắng xung quanh dấu phân cách hàng nghìn (ví dụ "42, 000" -> "42,000")
  static String normalizeThousandSeparators(String text) {
    return text.replaceAllMapped(
      RegExp(r'(?<=\d)\s*([.,])\s*(?=\d{3}(?!\d))'),
      (match) => match.group(1)!,
    );
  }

  /// Thử sửa các ký tự chữ dễ nhầm trong nhóm số sau dấu phân cách hàng nghìn
  /// (b, o, O, D, Q -> 0; l, I -> 1; S -> 5; B -> 8)
  static double? tryFixOcrAmount(String line) {
    final text = normalizeThousandSeparators(line);

    const fixMap = {
      'b': '0', 'o': '0', 'O': '0', 'd': '0', 'D': '0', 'q': '0', 'Q': '0',
      'l': '1', 'i': '1', 'I': '1',
      's': '5', 'S': '5',
      'B': '8',
    };

    final pattern = RegExp(r'(?<=\d)[.,]\s*([a-zA-Z0-9]{2,3})\b');
    final match = pattern.firstMatch(text);
    if (match != null) {
      var grp = match.group(1)!;
      if (grp.length == 2 && grp == '00') {
        grp = '000';
      } else if (grp.length == 3) {
        for (final entry in fixMap.entries) {
          grp = grp.replaceAll(entry.key, entry.value);
        }
      }
      if (RegExp(r'^\d{3}$').hasMatch(grp)) {
        final fixedLine = text.replaceRange(match.start, match.end, grp);
        final amt = _findLargestAmountInLine(fixedLine);
        if (amt != null && amt > 0) {
          return amt;
        }
      }
    }
    return null;
  }

  /// Kiểm tra xem một dòng có phải chỉ gồm đúng một số tiền hay không
  static bool _isOnlyAmountLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;

    // Bỏ qua mã số bắt đầu bằng 00 (như 000887)
    if (trimmed.startsWith('00') || (trimmed.length > 1 && trimmed.startsWith('0') && !trimmed.startsWith('0.') && !trimmed.startsWith('0,'))) {
      return false;
    }

    // Chuẩn hóa dấu phân cách
    final norm = normalizeThousandSeparators(trimmed);

    // Bỏ các ký hiệu tiền tệ
    final clean = norm.replaceAll(RegExp(r'(vnd|vnđ|đ|k|\$)', caseSensitive: false), '').trim();
    return RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(clean) ||
        (RegExp(r'^\d{4,}$').hasMatch(clean) && (int.tryParse(clean) ?? 0) % 100 == 0);
  }

  /// Quét tối đa maxLookahead (mặc định 2) dòng kế tiếp khi dòng từ khóa không có số.
  /// BƯỚC 3: Dòng kế tiếp phải CHỈ GỒM MỘT SỐ TIỀN mới được gắn cho từ khóa.
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

      // Cho phép vượt qua dòng kẻ phân cách (***, ---, ===)
      if (RegExp(r'^[\s*\-=_~]{3,}$').hasMatch(trimmed)) {
        continue;
      }

      if (_isGarbageLine(trimmed)) {
        checkedLines++;
        break; // Gặp dòng rác khác thì dừng, không nhảy cóc bừa bãi
      }

      final nextNorm = _normalizeText(trimmed);
      if (_isExcludedLine(nextNorm, allowCash: allowCash) || _isColumnHeader(nextNorm, trimmed)) {
        checkedLines++;
        break;
      }

      checkedLines++;

      // Chỉ gắn khi dòng này chỉ gồm một số tiền
      if (_isOnlyAmountLine(trimmed)) {
        final amount = _findLargestAmountInLine(trimmed);
        if (amount != null && amount > 0) {
          return amount;
        }
      } else {
        break;
      }
    }
    return null;
  }

  /// BƯỚC 5: Kiểm tra chéo tổng các món hàng
  /// Ứng viên X được xem là tổng khi X >= mọi ứng viên khác và X bằng
  /// tổng của TẤT CẢ ứng viên còn lại
  static CrossCheckResult? crossCheckTotal(
    List<String> lines,
    List<double> allAmounts,
  ) {
    if (lines.isEmpty || allAmounts.isEmpty) return null;

    final sortedCandidates = List.of(allAmounts)..sort((a, b) => b.compareTo(a));
    final maxX = sortedCandidates.first;
    if (maxX <= 0) return null;

    final validItemAmounts = <double>[];
    final suspiciousLines = <({int lineNum, String lineText, double? fixedVal})>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isGarbageLine(line)) continue;

      final norm = _normalizeText(line);
      if (_isExcludedLine(norm, allowCash: false)) continue;
      if (_isColumnHeader(norm, line)) continue;

      // Bỏ qua các dòng từ khóa tổng hoặc tiền mặt/thanh toán (đây không phải món hàng)
      final isTotalOrCash = _strongKeywords.any((kw) => norm.contains(kw)) ||
          _weakKeywords.any((kw) => norm.contains(kw)) ||
          norm.contains('tien mat') ||
          RegExp(r'\bcash\b').hasMatch(norm);
      if (isTotalOrCash) continue;

      // Dòng món hàng chứa chữ cái hoặc là dòng chỉ gồm một số tiền (trong hóa đơn OCR theo cột)
      final hasLetters = RegExp(r'[a-zA-Z\u00C0-\u1EF9]{2,}').hasMatch(norm);
      final isOnlyAmount = _isOnlyAmountLine(line);
      if (!hasLetters && !isOnlyAmount) continue;

      final lineAmounts = _findAllAmountsInLine(line);
      final validAmounts = lineAmounts.where((a) => a > 0 && (a - maxX).abs() > 0.01).toList();

      if (validAmounts.isNotEmpty) {
        validAmounts.sort((a, b) => b.compareTo(a));
        validItemAmounts.add(validAmounts.first);
      } else if (hasLetters) {
        final hasNumericTrace = RegExp(r'(\d|[.,]|b00|boo)').hasMatch(line);
        if (hasNumericTrace) {
          final fixed = tryFixOcrAmount(line);
          suspiciousLines.add((
            lineNum: i + 1,
            lineText: line,
            fixedVal: fixed,
          ));
        }
      }
    }

    if (validItemAmounts.length < 2) return null;

    final S = validItemAmounts.fold<double>(0.0, (sum, e) => sum + e);

    // 1. Khớp hoàn hảo không có dòng nghi ngờ
    if (suspiciousLines.isEmpty && (maxX - S).abs() < 1.0) {
      return CrossCheckResult(
        totalAmount: maxX,
        itemAmounts: validItemAmounts,
        suspiciousLineNumbers: [],
        inferredDiff: 0,
        isExact: true,
        description:
            'Khớp tổng tất cả các món: ${validItemAmounts.map((e) => e.toInt().toString()).join(' + ')} = ${maxX.toInt()} đ',
      );
    }

    // 2. Có dòng nghi ngờ và thử sửa thành công
    if (suspiciousLines.isNotEmpty) {
      final fixedSum = suspiciousLines.fold<double>(0.0, (sum, e) => sum + (e.fixedVal ?? 0.0));
      if (fixedSum > 0 && (maxX - (S + fixedSum)).abs() < 1.0) {
        final allFixedItems = [...validItemAmounts, ...suspiciousLines.map((e) => e.fixedVal ?? 0.0)];
        return CrossCheckResult(
          totalAmount: maxX,
          itemAmounts: allFixedItems,
          suspiciousLineNumbers: suspiciousLines.map((e) => e.lineNum).toList(),
          inferredDiff: fixedSum,
          isExact: true,
          description:
              'Khớp tổng sau khi sửa OCR: ${validItemAmounts.map((e) => e.toInt().toString()).join(' + ')} + ${suspiciousLines.map((e) => '${e.fixedVal?.toInt()} (dòng ${e.lineNum})').join(' + ')} = ${maxX.toInt()} đ',
        );
      }

      // 3. Có dòng nghi ngờ, maxX > S và độ lệch là bội số nguyên của 1000
      final diff = maxX - S;
      if (diff > 0 && (diff.toInt() % 1000 == 0) && (diff / suspiciousLines.length >= 1000)) {
        return CrossCheckResult(
          totalAmount: maxX,
          itemAmounts: validItemAmounts,
          suspiciousLineNumbers: suspiciousLines.map((e) => e.lineNum).toList(),
          inferredDiff: diff,
          isExact: false,
          description:
              'Khớp tổng, thiếu ${suspiciousLines.length} dòng nghi ngờ (${suspiciousLines.map((e) => 'dòng ${e.lineNum}').join(', ')}), giá trị suy ra ${diff.toInt()} đ',
        );
      }
    }

    return null;
  }

  /// Kiểm tra chéo bằng tổng tập con (Subset Sum) - giữ cho backward-compatibility
  static List<double>? findSubsetSum(List<double> candidates, double target) {
    final items = candidates
        .where((x) => x > 0 && x < target - 0.5)
        .toList();
    if (items.length < 2) return null;

    items.sort((a, b) => b.compareTo(a));
    final limitedItems = items.take(25).toList();

    List<double>? foundSubset;

    void backtrack(int index, double currentSum, List<double> currentList) {
      if (foundSubset != null) return;
      if ((currentSum - target).abs() < 1.0 && currentList.length >= 2) {
        foundSubset = List.of(currentList);
        return;
      }
      if (currentSum > target + 0.5) return;

      for (int i = index; i < limitedItems.length; i++) {
        currentList.add(limitedItems[i]);
        backtrack(i + 1, currentSum + limitedItems[i], currentList);
        currentList.removeLast();
        if (foundSubset != null) return;
      }
    }

    backtrack(0, 0.0, []);
    return foundSubset;
  }

  /// Bóc tách số tiền từ nội dung văn bản hóa đơn hoặc danh sách các hàng đã ghép tọa độ
  static double? extractAmount(String text, {List<String>? rows}) {
    if (text.trim().isEmpty && (rows == null || rows.isEmpty)) return null;

    final lines = (rows != null && rows.isNotEmpty)
        ? rows.map((l) => l.trim()).where((l) => l.isNotEmpty).toList()
        : text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return null;

    // (1) BƯỚC 4: Quét từ khóa MẠNH: lấy dòng khớp CUỐI CÙNG có số
    double? lastStrongAmount;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isGarbageLine(line)) continue;

      final normalized = _normalizeText(line);
      if (_isExcludedLine(normalized, allowCash: false)) continue;

      final hasStrong = _strongKeywords.any((kw) => normalized.contains(kw));
      if (hasStrong) {
        var amount = _findLargestAmountInLine(line);
        if (amount == null || amount <= 0) {
          amount = _findAmountInNextLines(lines, i, maxLookahead: 2, allowCash: false);
        }
        if (amount != null && amount > 0) {
          lastStrongAmount = amount;
        }
      }
    }

    if (lastStrongAmount != null) {
      return lastStrongAmount;
    }

    // (2) BƯỚC 4: Hàng "tiền mặt" / "thanh toán" có số khi hóa đơn KHÔNG có "tổng cộng"
    double? lastCashAmount;
    bool hasChangeKeyword = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isGarbageLine(line)) continue;

      final normalized = _normalizeText(line);
      if (normalized.contains('tien thoi') || normalized.contains('thoi lai')) {
        hasChangeKeyword = true;
      }

      final hasCash = normalized.contains('tien mat') ||
          RegExp(r'\bcash\b').hasMatch(normalized) ||
          normalized.contains('thanh toan');
      if (hasCash) {
        var amount = _findLargestAmountInLine(line);
        if (amount == null || amount <= 0) {
          amount = _findAmountInNextLines(lines, i, maxLookahead: 2, allowCash: true);
        }
        if (amount != null && amount > 0) {
          lastCashAmount = amount;
        }
      }
    }

    if (lastCashAmount != null && !hasChangeKeyword) {
      return lastCashAmount;
    }

    // Thu thập tất cả các số tiền
    final List<double> allAmounts = [];
    for (final line in lines) {
      if (_isGarbageLine(line)) continue;
      final lineAmounts = _findAllAmountsInLine(line);
      allAmounts.addAll(lineAmounts.where((a) => a > 0));
    }

    // (3) BƯỚC 4 & BƯỚC 5: KIỂM TRA CHÉO TỔNG (không bao giờ ghi đè bước 1 hoặc 2)
    final crossCheck = crossCheckTotal(lines, allAmounts);
    if (crossCheck != null) {
      return crossCheck.totalAmount;
    }

    // (4) HEURISTIC TOÁN HỌC: Max1 = Max2 + X (Tiền khách đưa = Bill + Tiền thối)
    if (hasChangeKeyword && allAmounts.length >= 2) {
      final sorted = List.of(allAmounts)..sort((a, b) => b.compareTo(a));
      final max1 = sorted[0];
      final max2 = sorted[1];
      if (max1 > max2) {
        for (int i = 2; i < sorted.length; i++) {
          final x = sorted[i];
          if ((max1 - (max2 + x)).abs() < 1.0) {
            return max2;
          }
        }
      }
    }

    // (5) TỪ KHÓA YẾU / SỐ LỚN NHẤT
    double? lastWeakAmount;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isGarbageLine(line)) continue;

      final normalized = _normalizeText(line);
      if (_isExcludedLine(normalized, allowCash: false)) continue;
      if (_isColumnHeader(normalized, line)) continue;

      final hasWeak = _weakKeywords.any((kw) => normalized.contains(kw));
      if (hasWeak) {
        var amount = _findLargestAmountInLine(line);
        if (amount == null || amount <= 0) {
          amount = _findAmountInNextLines(lines, i, maxLookahead: 2, allowCash: false);
        }
        if (amount != null && amount > 0) {
          lastWeakAmount = amount;
        }
      }
    }

    if (lastWeakAmount != null) {
      return lastWeakAmount;
    }

    if (allAmounts.isEmpty) return null;
    if (allAmounts.length == 1) return allAmounts.first;

    // Sắp xếp giảm dần (Descending)
    allAmounts.sort((a, b) => b.compareTo(a));
    return allAmounts.first;
  }

  /// Kiểm tra các dòng thông tin phụ, siêu dữ liệu không phải số tiền
  static bool _isGarbageLine(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.isEmpty) return true;

    // 1. URL / Web query
    if (RegExp(r'(=|&|\?q=|http|www|\.com)', caseSensitive: false).hasMatch(line)) {
      return true;
    }

    // 2. Ký tự phân cách (***, ---, ===)
    if (RegExp(r'^[\s*\-=_~]{3,}$').hasMatch(line)) {
      return true;
    }

    // 3. Thông tin liên hệ, số điện thoại
    if (RegExp(
      r'(^(dt|d/t|đ/t|tel|hotline|phone|dien\s*thoai|fax)\b)|'
      r'(\b(dt|d/t|đ/t|tel|hotline|phone|dien\s*thoai|fax)\s*[:.])|'
      r'(\b\d{6,11}\s*[-/]\s*\d{6,11}\b)|'
      r'(^(0\d{9,10}|\d{7,8})$)',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }

    // 4. Mã số thuế, số hóa đơn, số tài khoản
    if (RegExp(
      r'\b(mst|ma\s*so\s*thue|tax\s*code|so\s*hd|so\s*bill|so\s*phieu|inv\s*no|stk|tai\s*khoan)\b',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }

    // 5. Bàn số, quầy thu ngân, mã ca/máy
    if (RegExp(
      r'(\b(banso|ban\s*so|so\s*ban|table)\s*[:#]?\s*\d+)|'
      r'(\b(mc\s*#|pos\s*#|thu\s*ngan|cashier|nv\s*ban)\b)',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
    }

    // 6. Dòng ngày giờ độc lập không chứa từ khóa tiền tệ
    final dateRegex = RegExp(r'\b\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}\b');
    final timeRegex = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b');
    if ((dateRegex.hasMatch(line) || timeRegex.hasMatch(line)) &&
        !RegExp(r'\b(tong|total|tien|amount|vnd|đ|k)\b', caseSensitive: false).hasMatch(line)) {
      return true;
    }

    return false;
  }

  /// Bóc tách ngày tháng từ văn bản hóa đơn (dd/MM/yyyy, yyyy-MM-dd, dd-MM-yyyy, dd/MM/yy).
  /// BƯỚC 6: Năm có 5 chữ số như "13-11-20011" trả về null, không đoán sửa.
  static DateTime? extractDate(String text, {List<String>? rows}) {
    if (text.trim().isEmpty && (rows == null || rows.isEmpty)) return null;

    final lines = (rows != null && rows.isNotEmpty)
        ? rows.map((l) => l.trim()).where((l) => l.isNotEmpty).toList()
        : text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return null;

    // BƯỚC 6: Bỏ qua chuỗi ngày có năm 5 chữ số trở lên (ví dụ: 13-11-20011)
    final invalid5DigitYearRegex = RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{5,}\b');
    for (final line in lines) {
      if (invalid5DigitYearRegex.hasMatch(line)) {
        return null;
      }
    }

    final ymdRegex = RegExp(r'(?<!\d)(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)');
    final dmy4Regex = RegExp(r'(?<!\d)(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})(?!\d)');
    final dmy2Regex = RegExp(r'(?<!\d)(\d{1,2})[-/.](\d{1,2})[-/.](\d{2})(?!\d)');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 1. Khớp yyyy-MM-dd hoặc yyyy/MM/dd
      final ymdMatches = ymdRegex.allMatches(line);
      for (final match in ymdMatches) {
        final year = int.tryParse(match.group(1)!);
        final month = int.tryParse(match.group(2)!);
        final day = int.tryParse(match.group(3)!);
        if (year != null && month != null && day != null) {
          final time = _findTimeNearLine(lines, i);
          final date = _createValidDate(year, month, day, time[0], time[1], time[2]);
          if (date != null) return date;
        }
      }

      // 2. Khớp dd/MM/yyyy hoặc dd-MM-yyyy hoặc dd.MM.yyyy
      final dmy4Matches = dmy4Regex.allMatches(line);
      for (final match in dmy4Matches) {
        final day = int.tryParse(match.group(1)!);
        final month = int.tryParse(match.group(2)!);
        final year = int.tryParse(match.group(3)!);
        if (year != null && month != null && day != null) {
          final time = _findTimeNearLine(lines, i);
          final date = _createValidDate(year, month, day, time[0], time[1], time[2]);
          if (date != null) return date;
        }
      }

      // 3. Khớp dd/MM/yy hoặc dd-MM-yy hoặc dd.MM.yy (năm 2 chữ số -> 20yy)
      final dmy2Matches = dmy2Regex.allMatches(line);
      for (final match in dmy2Matches) {
        final day = int.tryParse(match.group(1)!);
        final month = int.tryParse(match.group(2)!);
        final yy = int.tryParse(match.group(3)!);
        if (yy != null && month != null && day != null) {
          final year = 2000 + yy;
          final time = _findTimeNearLine(lines, i);
          final date = _createValidDate(year, month, day, time[0], time[1], time[2]);
          if (date != null) return date;
        }
      }
    }

    return null;
  }

  /// Bóc tách tên cửa hàng dựa trên từ khóa nhận diện hoặc dòng văn bản đầu tiên hợp lệ.
  static String? extractMerchantName(String text, {List<String>? rows}) {
    if (text.trim().isEmpty && (rows == null || rows.isEmpty)) return null;

    final lines = (rows != null && rows.isNotEmpty)
        ? rows.map((l) => l.trim()).where((l) => l.isNotEmpty).toList()
        : text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return null;

    final urlGarbageRegex = RegExp(
      r'(=|&|\?q=|http|www|\.com)',
      caseSensitive: false,
    );

    final merchantKeywords = RegExp(
      r'(qu[aá]n\s*[aá]n|qu[aá]n|c[uử]a\s*h[aà]ng|si[eê]u\s*th[iị]|coopmart|co\.opmart|winmart|circle\s*k|b[aá]ch\s*h[oó]a\s*xanh|nh[aà]\s*h[aà]ng|coffee|cafe|highlands|ph[uú]c\s*long|familymart|gs25|7-eleven|ministop|kfc|lotteria|jollibee|store|shop)',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (!urlGarbageRegex.hasMatch(line) && merchantKeywords.hasMatch(line)) {
        return _cleanMerchantName(line);
      }
    }

    final skipPatterns = RegExp(
      r'^(h[oó]a\s*đ[oơ]n|phi[eế]u|receipt|bill|mst|m[aã]\s*s[oố]\s*thu[eế]|đ[iị]a\s*ch[iỉ]|đ/c|address|tel|hotline|\d+)',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (!urlGarbageRegex.hasMatch(line) && !skipPatterns.hasMatch(line) && line.length >= 3) {
        return _cleanMerchantName(line);
      }
    }

    for (final line in lines) {
      if (!urlGarbageRegex.hasMatch(line)) {
        return _cleanMerchantName(line);
      }
    }

    return _cleanMerchantName(lines.first);
  }

  // --- Helper Methods ---

  static double? _findLargestAmountInLine(String line) {
    final amounts = _findAllAmountsInLine(line);
    if (amounts.isEmpty) return null;
    amounts.sort((a, b) => b.compareTo(a));
    return amounts.first;
  }

  static List<double> _findAllAmountsInLine(String line) {
    final List<double> results = [];

    // BƯỚC 3: Gộp dấu cách xung quanh dấu phân cách hàng nghìn
    final normalized = normalizeThousandSeparators(line);

    // Khớp định dạng kết thúc bằng k (ví dụ: 150k, 150.5k)
    final kRegex = RegExp(r'(?<![a-zA-Z#\u00C0-\u1EF9])(\d+(?:[.,]\d+)?)\s*[kK]\b');
    for (final match in kRegex.allMatches(normalized)) {
      final numStr = match.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      if (val != null) {
        results.add(val * 1000);
      }
    }

    // Loại bỏ chuỗi định dạng số điện thoại gạch nối nếu có (ví dụ: 9407863-8259956)
    final cleanLine = normalized.replaceAll(RegExp(r'\b\d{6,11}\s*[-/]\s*\d{6,11}\b'), '');

    // Khớp các con số thông thường hoặc có phân cách hàng nghìn (150.000, 150,000, 150000)
    // BƯỚC 3: Chống rác - Bỏ qua token dính liền chữ cái (F1304, MC#01)
    final numberRegex = RegExp(
      r'(?<![a-zA-Z#\u00C0-\u1EF9])(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d{4,}(?:[.,]\d{1,2})?|\d{1,3}(?:[.,]\d{1,2}))(?![a-zA-Z\u00C0-\u1EF9])',
    );

    for (final match in numberRegex.allMatches(cleanLine)) {
      final raw = match.group(1)!;
      final parsed = _parseNumericString(raw, cleanLine);
      if (parsed != null && !results.contains(parsed)) {
        results.add(parsed);
      }
    }

    return results;
  }

  static double? _parseNumericString(String raw, [String contextLine = '']) {
    var s = raw.replaceAll(RegExp(r'\s+'), '');

    // BƯỚC 3: Chống rác - Token bắt đầu bằng số 0 dài (ví dụ "000887")
    if (s.startsWith('00') || (s.length > 1 && s.startsWith('0') && !s.startsWith('0.') && !s.startsWith('0,'))) {
      return null;
    }

    // 150.000 hoặc 150,000
    if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(s)) {
      s = s.replaceAll(RegExp(r'[.,]'), '');
      return double.tryParse(s);
    }

    // 1.250.000,00 hoặc 1,250,000.00
    if (RegExp(r'^\d{1,3}([.,]\d{3})+[.,]\d{1,2}$').hasMatch(s)) {
      final decSep = s[s.length - 3] == '.' || s[s.length - 3] == ','
          ? s[s.length - 3]
          : s[s.length - 2];
      final thousandSep = decSep == '.' ? ',' : '.';
      s = s.replaceAll(thousandSep, '').replaceAll(decSep, '.');
      return double.tryParse(s);
    }

    // Số chỉ có dấu chấm hoặc phẩy đơn (ví dụ 150.000 hoặc 15.5)
    if (s.contains('.') && !s.contains(',')) {
      final parts = s.split('.');
      if (parts.last.length == 3) {
        s = s.replaceAll('.', '');
      }
    } else if (s.contains(',') && !s.contains('.')) {
      final parts = s.split(',');
      if (parts.last.length == 3) {
        s = s.replaceAll(',', '');
      } else {
        s = s.replaceAll(',', '.');
      }
    } else {
      // Số thuần không có dấu chấm/phẩy (ví dụ: 537000 hoặc 1304 hoặc 9407863)
      final val = double.tryParse(s);
      if (val == null) return null;

      final normLine = _normalizeText(contextLine);
      final hasCashOrTotal = normLine.contains('tien mat') ||
          normLine.contains('tong') ||
          normLine.contains('total') ||
          normLine.contains('thanh toan') ||
          normLine.contains('cash');

      // BƯỚC 3: Số dạng "537000" ở hàng chứa từ khóa tiền mặt/tổng được nhận ngay
      if (hasCashOrTotal && val >= 1000) {
        return val;
      }

      // Nếu có từ 7 chữ số trở lên (>= 1.000.000) mà không có đơn vị: thường là SĐT
      if (s.length >= 7) {
        final hasCurrency = RegExp(r'(vnd|vnđ|đ|tiền|tien|tổng|tong)', caseSensitive: false).hasMatch(contextLine);
        if (!hasCurrency) return null;
      }

      // BƯỚC 3: Số trần chỉ nhận làm tiền khi là bội số của 100
      if (val >= 1000 && (val.toInt() % 100 == 0)) {
        return val;
      }

      return null;
    }

    return double.tryParse(s);
  }

  static List<int> _findTimeNearLine(List<String> lines, int i) {
    var time = _extractTime(lines[i]);
    if (time != null) return time;

    if (i + 1 < lines.length) {
      time = _extractTime(lines[i + 1]);
      if (time != null) return time;
    }

    if (i - 1 >= 0) {
      time = _extractTime(lines[i - 1]);
      if (time != null) return time;
    }

    return [0, 0, 0];
  }

  static List<int>? _extractTime(String line) {
    final timeRegex = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?\b');
    final match = timeRegex.firstMatch(line);
    if (match != null) {
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final second = match.group(3) != null ? int.parse(match.group(3)!) : 0;
      return [hour, minute, second];
    }
    return null;
  }

  static DateTime? _createValidDate(
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
    int second = 0,
  ]) {
    if (year < 2000 || year > 2100) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (hour < 0 || hour > 23) return null;
    if (minute < 0 || minute > 59) return null;
    if (second < 0 || second > 59) return null;

    try {
      final dt = DateTime(year, month, day, hour, minute, second);
      if (dt.year != year || dt.month != month || dt.day != day) {
        return null;
      }
      return dt;
    } catch (_) {
      return null;
    }
  }

  static String _cleanMerchantName(String raw) {
    return raw
        .replaceAll(RegExp(r'^[^\w\s\p{L}]+|[^\w\s\p{L}]+$', unicode: true), '')
        .trim();
  }
}
