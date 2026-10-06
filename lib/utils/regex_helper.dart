import 'dart:math' as math;

class RegexHelper {
  /// Bóc tách số tiền từ nội dung văn bản hóa đơn.
  /// Hỗ trợ định dạng Việt Nam: 150.000, 150,000 VND, 150k, v.v.
  static double? extractAmount(String text) {
    if (text.trim().isEmpty) return null;

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return null;

    // Các từ khóa ưu tiên chỉ tổng tiền (loại trừ tuyệt đối: tiền mặt, cash, tiền thối)
    final totalKeywords = RegExp(
      r'(t[oổ]ng\s*c[oộ]ng|t[oổ]ng\s*ti[eề]n|th[aà]nh\s*ti[eề]n|t[oổ]ng\s*thanh\s*to[aá]n|total|amount)',
      caseSensitive: false,
    );

    // 1. Duyệt từng dòng từ trên xuống dưới, ưu tiên từ khóa tổng tiền và return ngay lập tức
    for (final line in lines) {
      if (totalKeywords.hasMatch(line)) {
        final amount = _findLargestAmountInLine(line);
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }

    // 2. Fallback: Quét toàn bộ văn bản để lấy danh sách tất cả số tiền và lấy con số LỚN NHẤT
    final List<double> allAmounts = [];
    for (final line in lines) {
      final lineAmounts = _findAllAmountsInLine(line);
      allAmounts.addAll(lineAmounts.where((a) => a > 0));
    }

    if (allAmounts.isEmpty) return null;

    // Tổng bill luôn là con số lớn nhất trên hóa đơn
    return allAmounts.reduce(math.max);
  }

  /// Bóc tách ngày tháng từ văn bản hóa đơn (dd/MM/yyyy, yyyy-MM-dd, dd-MM-yyyy).
  static DateTime? extractDate(String text) {
    if (text.trim().isEmpty) return null;

    // 1. Khớp yyyy-MM-dd hoặc yyyy/MM/dd
    final ymdRegex = RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b');
    final ymdMatches = ymdRegex.allMatches(text);
    for (final match in ymdMatches) {
      final year = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      final day = int.tryParse(match.group(3)!);
      if (year != null && month != null && day != null) {
        final date = _createValidDate(year, month, day);
        if (date != null) return date;
      }
    }

    // 2. Khớp dd/MM/yyyy hoặc dd-MM-yyyy hoặc dd.MM.yyyy
    final dmyRegex = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})\b');
    final dmyMatches = dmyRegex.allMatches(text);
    for (final match in dmyMatches) {
      final day = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      final year = int.tryParse(match.group(3)!);
      if (year != null && month != null && day != null) {
        final date = _createValidDate(year, month, day);
        if (date != null) return date;
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
      r'(c[uử]a\s*h[aà]ng|si[eê]u\s*th[iị]|coopmart|co\.opmart|winmart|circle\s*k|b[aá]ch\s*h[oó]a\s*xanh|nh[aà]\s*h[aà]ng|coffee|cafe|highlands|ph[uú]c\s*long|familymart|gs25|7-eleven|ministop|kfc|lotteria|jollibee|store|shop)',
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

    // Khớp các con số thông thường hoặc có phân cách hàng nghìn (150.000, 150,000, 150000)
    final numberRegex = RegExp(
      r'(\d{1,3}(?:[.,\s]\d{3})+(?:[.,]\d{1,2})?|\d{4,}(?:[.,]\d{1,2})?|\d{1,3}(?:[.,]\d{1,2}))',
    );

    for (final match in numberRegex.allMatches(line)) {
      final raw = match.group(0)!;
      final parsed = _parseNumericString(raw);
      if (parsed != null && !results.contains(parsed)) {
        results.add(parsed);
      }
    }

    return results;
  }

  static double? _parseNumericString(String raw) {
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
    }

    return double.tryParse(s);
  }

  static DateTime? _createValidDate(int year, int month, int day) {
    if (year < 2000 || year > 2100) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    try {
      return DateTime(year, month, day);
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
