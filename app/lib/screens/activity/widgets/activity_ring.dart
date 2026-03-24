import 'dart:math';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';

/// A circular activity ring widget inspired by Apple Watch activity rings.
///
/// Displays up to three concentric rings: active time, play time, and rest
/// time. Each ring fills proportionally to [value] (0.0 → 1.0).
class ActivityRing extends StatelessWidget {
  /// Progress value between 0.0 and 1.0.
  final double activeValue;
  final double playValue;
  final double restValue;

  /// Labels shown in the centre of the rings.
  final String centerLabel;
  final String centerSublabel;

  /// Outer radius of the outermost ring.
  final double radius;

  /// Stroke width for each ring.
  final double strokeWidth;

  const ActivityRing({
    super.key,
    required this.activeValue,
    required this.playValue,
    required this.restValue,
    this.centerLabel = '',
    this.centerSublabel = '',
    this.radius = 80,
    this.strokeWidth = 16,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2 + strokeWidth;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ActivityRingPainter(
          activeValue: activeValue.clamp(0.0, 1.0),
          playValue: playValue.clamp(0.0, 1.0),
          restValue: restValue.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          activeColor: AppColors.primary,
          playColor: AppColors.accent,
          restColor: Colors.indigo,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (centerLabel.isNotEmpty)
                Text(
                  centerLabel,
                  style: TextStyle(
                    fontSize: radius * 0.22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              if (centerSublabel.isNotEmpty)
                Text(
                  centerSublabel,
                  style: TextStyle(
                    fontSize: radius * 0.14,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRingPainter extends CustomPainter {
  final double activeValue;
  final double playValue;
  final double restValue;
  final double strokeWidth;
  final Color activeColor;
  final Color playColor;
  final Color restColor;

  const _ActivityRingPainter({
    required this.activeValue,
    required this.playValue,
    required this.restValue,
    required this.strokeWidth,
    required this.activeColor,
    required this.playColor,
    required this.restColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Three rings: outermost = active, middle = play, inner = rest
    final gaps = strokeWidth * 0.3;
    final outerRadius = size.width / 2 - strokeWidth / 2;
    final middleRadius = outerRadius - strokeWidth - gaps;
    final innerRadius = middleRadius - strokeWidth - gaps;

    _drawRing(canvas, center, outerRadius, activeValue, activeColor);
    _drawRing(canvas, center, middleRadius, playValue, playColor);
    _drawRing(canvas, center, innerRadius, restValue, restColor);
  }

  void _drawRing(Canvas canvas, Offset center, double radius, double value,
      Color color) {
    // Background track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withOpacity(0.12)
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (value <= 0) return;

    // Foreground arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * value;
    final rect = Rect.fromCircle(center: center, radius: radius);
    // Start from the top (-π/2)
    canvas.drawArc(rect, -pi / 2, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(_ActivityRingPainter old) =>
      old.activeValue != activeValue ||
      old.playValue != playValue ||
      old.restValue != restValue;
}

/// A compact legend row to place below the [ActivityRing].
class ActivityRingLegend extends StatelessWidget {
  const ActivityRingLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _LegendDot(color: AppColors.primary, label: 'Active'),
        SizedBox(width: 16),
        _LegendDot(color: AppColors.accent, label: 'Play'),
        SizedBox(width: 16),
        _LegendDot(color: Colors.indigo, label: 'Rest'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600)),
      ],
    );
  }
}
