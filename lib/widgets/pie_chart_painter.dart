import 'dart:math' as math;
import 'package:flutter/material.dart';

class PieChartPainter extends CustomPainter {
  final Map<String, double> categoryData;
  final double progress;
  final double strokeWidth;
  final Map<String, Color>? categoryColors;

  static const List<Color> _defaultPalette = [
    Color(0xFFFF7043), // Orange / Food
    Color(0xFF42A5F5), // Blue / Study
    Color(0xFF26A69A), // Teal / Travel
    Color(0xFFAB47BC), // Purple / Gear
    Color(0xFFEC407A), // Pink / Entertainment
    Color(0xFFFFA726), // Amber
    Color(0xFF26C6DA), // Cyan
    Color(0xFF7E57C2), // Deep Purple
  ];

  static const Map<String, Color> _knownCategoryColors = {
    'food': Color(0xFFFF7043),
    'Ăn uống': Color(0xFFFF7043),
    'study': Color(0xFF42A5F5),
    'Học tập': Color(0xFF42A5F5),
    'travel': Color(0xFF26A69A),
    'Di chuyển': Color(0xFF26A69A),
    'gear': Color(0xFFAB47BC),
    'Thiết bị': Color(0xFFAB47BC),
    'entertainment': Color(0xFFEC407A),
    'Giải trí': Color(0xFFEC407A),
  };

  PieChartPainter({
    required this.categoryData,
    this.progress = 1.0,
    this.strokeWidth = 26.0,
    this.categoryColors,
  });

  Color _getColor(String category, int index) {
    if (categoryColors != null && categoryColors!.containsKey(category)) {
      return categoryColors![category]!;
    }
    if (_knownCategoryColors.containsKey(category)) {
      return _knownCategoryColors[category]!;
    }
    return _defaultPalette[index % _defaultPalette.length];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    if (radius <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Filter valid positive entries
    final validEntries = categoryData.entries
        .where((e) => e.value > 0)
        .toList();

    final totalAmount = validEntries.fold<double>(
      0.0,
      (sum, item) => sum + item.value,
    );

    // Empty state: draw a grey ring
    if (totalAmount <= 0 || validEntries.isEmpty) {
      final emptyPaint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, emptyPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Chưa có\ndữ liệu',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius * 1.4);

      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2,
        ),
      );
      return;
    }

    // Normal state: draw animated arcs
    double startAngle = -math.pi / 2; // 12 o'clock
    final maxTotalSweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    double accumulatedSweep = 0.0;

    int colorIndex = 0;
    for (final entry in validEntries) {
      final sliceRatio = entry.value / totalAmount;
      final targetSliceSweep = sliceRatio * 2 * math.pi;

      // Calculate how much of this slice should be drawn given current progress
      final remainingAllowedSweep = maxTotalSweep - accumulatedSweep;
      if (remainingAllowedSweep <= 0) break;

      final actualSliceSweep = math.min(targetSliceSweep, remainingAllowedSweep);

      final paint = Paint()
        ..color = _getColor(entry.key, colorIndex++)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        rect,
        startAngle,
        actualSliceSweep,
        false,
        paint,
      );

      startAngle += actualSliceSweep;
      accumulatedSweep += actualSliceSweep;
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.categoryData != categoryData ||
        oldDelegate.categoryColors != categoryColors;
  }
}

