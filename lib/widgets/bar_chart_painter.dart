import 'dart:math' as math;
import 'package:flutter/material.dart';

class BarChartPainter extends CustomPainter {
  final List<double> dailyExpenses;
  final List<String> dayLabels;
  final double progress;
  final Color barColor;
  final Color trackColor;

  static const List<String> defaultDayLabels = [
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];

  BarChartPainter({
    required this.dailyExpenses,
    List<String>? dayLabels,
    this.progress = 1.0,
    this.barColor = const Color(0xFF1E88E5), // Material Blue 600
    Color? trackColor,
  })  : dayLabels = dayLabels ?? defaultDayLabels,
        trackColor = trackColor ?? const Color(0xFFEEEEEE);

  @override
  void paint(Canvas canvas, Size size) {
    final count = math.max(dailyExpenses.length, dayLabels.length);
    if (count == 0) return;

    const labelHeight = 22.0;
    const topPadding = 12.0;
    final chartHeight = size.height - labelHeight - topPadding;
    final baselineY = size.height - labelHeight;

    // Draw baseline
    final baselinePaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      baselinePaint,
    );

    // Calculate maximum expense value for proportional scaling
    double maxAmount = 0.0;
    for (final amount in dailyExpenses) {
      if (amount > maxAmount) {
        maxAmount = amount;
      }
    }

    final slotWidth = size.width / count;
    final barWidth = math.min(slotWidth * 0.48, 28.0);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final centerX = i * slotWidth + slotWidth / 2;
      final left = centerX - barWidth / 2;

      // Draw subtle background slot track
      final trackRect = Rect.fromLTWH(
        left,
        topPadding,
        barWidth,
        chartHeight,
      );
      canvas.drawRect(trackRect, trackPaint);

      // Draw value bar using canvas.drawRect
      final amount = i < dailyExpenses.length ? dailyExpenses[i] : 0.0;
      if (maxAmount > 0 && amount > 0) {
        final ratio = (amount / maxAmount).clamp(0.0, 1.0);
        final animatedHeight = chartHeight * ratio * progress.clamp(0.0, 1.0);
        final top = baselineY - animatedHeight;

        final barRect = Rect.fromLTWH(
          left,
          top,
          barWidth,
          animatedHeight,
        );
        canvas.drawRect(barRect, barPaint);
      }

      // Draw day label text below baseline
      final label = i < dayLabels.length ? dayLabels[i] : '';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          centerX - textPainter.width / 2,
          baselineY + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.barColor != barColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.dailyExpenses != dailyExpenses ||
        oldDelegate.dayLabels != dayLabels;
  }
}

