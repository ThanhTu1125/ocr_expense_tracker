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
  /// Gom các dòng cùng hàng theo vị trí tọa độ
  /// - Sắp xếp theo tâm dọc
  /// - Gom dòng cùng hàng nếu:
  ///   + Độ chồng lấp theo chiều dọc > 50% chiều cao nhỏ hơn, HOẶC
  ///   + |Chênh lệch tâm y| < 0.6 x chiều cao trung vị
  /// - Trong mỗi hàng, sắp xếp theo x từ trái qua phải và nối bằng một dấu cách
  static List<String> reconstructRows(List<OcrLine> lines) {
    if (lines.isEmpty) return [];

    final validLines = lines
        .where((l) => l.text.trim().isNotEmpty && l.boundingBox.height > 0)
        .toList();
    if (validLines.isEmpty) return [];

    // Tính chiều cao trung vị (median height)
    final heights = validLines.map((l) => l.boundingBox.height).toList()..sort();
    final medianHeight = heights[heights.length ~/ 2];

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
      final rowTop = lastRow.map((l) => l.boundingBox.top).reduce(min);
      final rowBottom = lastRow.map((l) => l.boundingBox.bottom).reduce(max);
      final rowCenterY = (rowTop + rowBottom) / 2;
      final rowHeight = lastRow.map((l) => l.boundingBox.height).reduce((a, b) => a + b) / lastRow.length;

      final overlapTop = max(line.boundingBox.top, rowTop);
      final overlapBottom = min(line.boundingBox.bottom, rowBottom);
      final overlapY = max(0.0, overlapBottom - overlapTop);
      final minH = min(line.boundingBox.height, rowHeight);

      final isOverlap = minH > 0 && (overlapY / minH) > 0.5;
      final isCenterClose =
          (line.boundingBox.center.dy - rowCenterY).abs() < (0.6 * medianHeight);

      if (isOverlap || isCenterClose) {
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
