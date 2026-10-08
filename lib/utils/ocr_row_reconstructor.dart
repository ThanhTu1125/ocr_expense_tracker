import 'dart:math';
import 'dart:ui';

/// Đại diện cho một dòng chữ có tọa độ hình chữ nhật (boundingBox)
class OcrLine {
  final String text;
  final Rect boundingBox;

  const OcrLine({
    required this.text,
    required this.boundingBox,
  });
}

/// Kết quả OCR đầy đủ gồm văn bản thô và danh sách các dòng kèm tọa độ
class OcrResult {
  final String text;
  final List<OcrLine> lines;

  const OcrResult({
    required this.text,
    required this.lines,
  });
}

/// Tiện ích ghép dòng theo tọa độ hình học (Pure functions)
class OcrRowReconstructor {
  /// Gom các dòng cùng hàng theo vị trí tọa độ:
  /// - Tâm y chênh nhau < 0.8 x chiều cao LỚN HƠN của cặp, HOẶC
  /// - Vùng chồng lấp dọc > 30% chiều cao NHỎ HƠN của cặp
  /// - ĐỒNG THỜI hai dòng không chồng lấp theo chiều ngang (overlapX <= 15% width nhỏ hơn)
  /// - Trong mỗi hàng, sắp xếp theo x từ trái qua phải và nối bằng một dấu cách
  static List<String> reconstructRows(List<OcrLine> lines) {
    if (lines.isEmpty) return [];

    final validLines = lines
        .where((l) => l.text.trim().isNotEmpty && l.boundingBox.height > 0)
        .toList();
    if (validLines.isEmpty) return [];

    // Sắp xếp các line theo tâm dọc
    final sortedByY = List<OcrLine>.from(validLines)
      ..sort((a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));

    final List<List<OcrLine>> rows = [];

    for (final line in sortedByY) {
      if (rows.isEmpty) {
        rows.add([line]);
        continue;
      }

      final lastRow = rows.last;
      final refLine = lastRow.last;

      final maxH = max(line.boundingBox.height, refLine.boundingBox.height);
      final minH = min(line.boundingBox.height, refLine.boundingBox.height);
      final cyDiff = (line.boundingBox.center.dy - refLine.boundingBox.center.dy).abs();

      final overlapTop = max(line.boundingBox.top, refLine.boundingBox.top);
      final overlapBottom = min(line.boundingBox.bottom, refLine.boundingBox.bottom);
      final overlapY = max(0.0, overlapBottom - overlapTop);
      final isVerticalOverlap = minH > 0 && (overlapY / minH) > 0.3;

      final isCenterClose = cyDiff < (0.8 * maxH);

      // Kiểm tra không chồng lấp ngang
      final overlapLeft = max(line.boundingBox.left, refLine.boundingBox.left);
      final overlapRight = min(line.boundingBox.right, refLine.boundingBox.right);
      final overlapX = max(0.0, overlapRight - overlapLeft);
      final minW = min(line.boundingBox.width, refLine.boundingBox.width);
      final noHorizontalOverlap = minW > 0 ? (overlapX / minW) <= 0.15 : true;

      if ((isCenterClose || isVerticalOverlap) && noHorizontalOverlap) {
        lastRow.add(line);
      } else {
        rows.add([line]);
      }
    }

    final result = <String>[];
    for (final row in rows) {
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      final rowText = row
          .map((l) => l.text.trim())
          .where((t) => t.isNotEmpty)
          .join(' ');
      if (rowText.isNotEmpty) {
        result.add(rowText);
      }
    }

    return result;
  }
}
