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
    'tien mat',
    'tien thoi',
    'thoi lai',
    'so luong',
  ];

  static bool _isExcludedLine(String normalized) {
    for (final kw in _excludedKeywords) {
      if (normalized.contains(kw)) return true;
    }
    if (RegExp(r'\bv\.?a\.?t\b').hasMatch(normalized)) return true;
    if (RegExp(r'\bthue\b').hasMatch(normalized)) return true;
    if (RegExp(r'\bcash\b').hasMatch(normalized)) return true;
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

  /// Bóc tách số tiền từ nội dung văn bản hóa đơn.
  /// Hỗ trợ định dạng Việt Nam: 150.000, 150,000 VND, 150k, v.v.
  static double? extractAmount(String text) {
    if (text.trim().isEmpty) return null;

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return null;

    // 1. Quét từ khóa MẠNH: nếu có dòng khớp từ khóa mạnh, lấy dòng khớp CUỐI CÙNG có số
    double? lastStrongAmount;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isGarbageLine(line)) continue;

      final normalized = _normalizeText(line);
      if (_isExcludedLine(normalized)) continue;

      final hasStrong = _strongKeywords.any((kw) => normalized.contains(kw));
      if (hasStrong) {
        var amount = _findLargestAmountInLine(line);
        if (amount == null || amount <= 0) {
          // Nếu dòng chứa từ khóa không có số tiền, kiểm tra dòng tiếp theo (thường gặp khi ngắt dòng)
          if (i + 1 < lines.length && !_isGarbageLine(lines[i + 1])) {
            final nextNorm = _normalizeText(lines[i + 1]);
            if (!_isExcludedLine(nextNorm)) {
              amount = _findLargestAmountInLine(lines[i + 1]);
            }
          }
        }
        if (amount != null && amount > 0) {
          lastStrongAmount = amount;
        }
      }
    }

    if (lastStrongAmount != null) {
      return lastStrongAmount;
    }

    // 2. Quét từ khóa YẾU: chỉ khi không có từ khóa mạnh, lấy dòng khớp CUỐI CÙNG có số
    double? lastWeakAmount;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isGarbageLine(line)) continue;

      final normalized = _normalizeText(line);
      if (_isExcludedLine(normalized)) continue;
      if (_isColumnHeader(normalized, line)) continue;

      final hasWeak = _weakKeywords.any((kw) => normalized.contains(kw));
      if (hasWeak) {
        var amount = _findLargestAmountInLine(line);
        if (amount == null || amount <= 0) {
          if (i + 1 < lines.length && !_isGarbageLine(lines[i + 1])) {
            final nextNorm = _normalizeText(lines[i + 1]);
            if (!_isExcludedLine(nextNorm) && !_isColumnHeader(nextNorm, lines[i + 1])) {
              amount = _findLargestAmountInLine(lines[i + 1]);
            }
          }
        }
        if (amount != null && amount > 0) {
          lastWeakAmount = amount;
        }
      }
    }

    if (lastWeakAmount != null) {
      return lastWeakAmount;
    }

    // 3. Logic Fallback: Heuristic Toán học
    final List<double> allAmounts = [];
    for (final line in lines) {
      if (_isGarbageLine(line)) continue;

      final lineAmounts = _findAllAmountsInLine(line);
      allAmounts.addAll(lineAmounts.where((a) => a > 0));
    }

    if (allAmounts.isEmpty) return null;
    if (allAmounts.length == 1) return allAmounts.first;

    // Sắp xếp giảm dần (Descending)
    allAmounts.sort((a, b) => b.compareTo(a));

    final max1 = allAmounts[0];
    final max2 = allAmounts[1];

    // Kiểm tra Heuristic Toán học: Tìm X thỏa mãn Max1 == Max2 + X
    if (max1 > max2) {
      for (int i = 2; i < allAmounts.length; i++) {
        final x = allAmounts[i];
        if ((max1 - (max2 + x)).abs() < 1.0) {
          // Max1 là Tiền khách đưa, Max2 là Tổng bill, X là Tiền thối
          return max2;
        }
      }
    }

    // Không có tiền thối: số lớn nhất chính là tổng bill
    return max1;
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
  /// Gán giờ (HH:mm[:ss]) nếu có cùng dòng hoặc kế bên.
  static DateTime? extractDate(String text) {
    if (text.trim().isEmpty) return null;

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return null;

    final ymdRegex = RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b');
    final dmy4Regex = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})\b');
    final dmy2Regex = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2})\b');

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
  static String? extractMerchantName(String text) {
    if (text.trim().isEmpty) return null;

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return null;

    // Bộ lọc nhận diện và loại bỏ rác URL / Web link / Query string
    final urlGarbageRegex = RegExp(
      r'(=|&|\?q=|http|www|\.com)',
      caseSensitive: false,
    );

    // Các từ khóa đặc trưng của cửa hàng / thương hiệu bán lẻ
    final merchantKeywords = RegExp(
      r'(qu[aá]n\s*[aá]n|qu[aá]n|c[uử]a\s*h[aà]ng|si[eê]u\s*th[iị]|coopmart|co\.opmart|winmart|circle\s*k|b[aá]ch\s*h[oó]a\s*xanh|nh[aà]\s*h[aà]ng|coffee|cafe|highlands|ph[uú]c\s*long|familymart|gs25|7-eleven|ministop|kfc|lotteria|jollibee|store|shop)',
      caseSensitive: false,
    );

    // 1. Tìm dòng có từ khóa cửa hàng / thương hiệu (bỏ qua dòng URL)
    for (final line in lines) {
      if (!urlGarbageRegex.hasMatch(line) && merchantKeywords.hasMatch(line)) {
        return _cleanMerchantName(line);
      }
    }

    // 2. Heuristic fallback: Lấy dòng đầu tiên không phải URL, tiêu đề hóa đơn hay mã số thuế / địa chỉ
    final skipPatterns = RegExp(
      r'^(h[oó]a\s*đ[oơ]n|phi[eế]u|receipt|bill|mst|m[aã]\s*s[oố]\s*thu[eế]|đ[iị]a\s*ch[iỉ]|đ/c|address|tel|hotline|\d+)',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (!urlGarbageRegex.hasMatch(line) && !skipPatterns.hasMatch(line) && line.length >= 3) {
        return _cleanMerchantName(line);
      }
    }

    // 3. Fallback cuối: Lấy dòng đầu tiên hợp lệ không chứa URL
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

    // Khớp định dạng kết thúc bằng k (ví dụ: 150k, 150.5k)
    final kRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*[kK]\b');
    for (final match in kRegex.allMatches(line)) {
      final numStr = match.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      if (val != null) {
        results.add(val * 1000);
      }
    }

    // Loại bỏ chuỗi định dạng số điện thoại gạch nối nếu có (ví dụ: 9407863-8259956)
    final cleanLine = line.replaceAll(RegExp(r'\b\d{6,11}\s*[-/]\s*\d{6,11}\b'), '');

    // Khớp các con số thông thường hoặc có phân cách hàng nghìn (150.000, 150,000, 150000)
    final numberRegex = RegExp(
      r'(\d{1,3}(?:[.,\s]\d{3})+(?:[.,]\d{1,2})?|\d{4,}(?:[.,]\d{1,2})?|\d{1,3}(?:[.,]\d{1,2}))',
    );

    for (final match in numberRegex.allMatches(cleanLine)) {
      final raw = match.group(0)!;
      final parsed = _parseNumericString(raw, cleanLine);
      if (parsed != null && !results.contains(parsed)) {
        results.add(parsed);
      }
    }

    return results;
  }

  static double? _parseNumericString(String raw, [String contextLine = '']) {
    var s = raw.replaceAll(RegExp(r'\s+'), '');

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
      // Số thuần không có dấu chấm/phẩy (ví dụ: 150000 hoặc 9407863)
      // Nếu có từ 7 chữ số trở lên (>= 1.000.000) mà không có dấu phân cách hoặc đơn vị tiền tệ:
      // Thường là số điện thoại hoặc mã số, ta bỏ qua
      if (s.length >= 7) {
        final hasCurrency = RegExp(r'(vnd|vnđ|đ|tiền|tien|tổng|tong)', caseSensitive: false).hasMatch(contextLine);
        if (!hasCurrency) {
          return null;
        }
      }
    }

    return double.tryParse(s);
  }

  static List<int> _findTimeNearLine(List<String> lines, int i) {
    // 1. Ưu tiên giờ cùng dòng
    var time = _extractTime(lines[i]);
    if (time != null) return time;

    // 2. Kiểm tra dòng kế tiếp
    if (i + 1 < lines.length) {
      time = _extractTime(lines[i + 1]);
      if (time != null) return time;
    }

    // 3. Kiểm tra dòng ngay trước
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
      // Validate ngày thật: kiểm tra year/month/day khớp lại đầu vào để ngăn chặn overflow
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
