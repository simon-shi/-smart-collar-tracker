import 'dart:math';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';

/// A compass widget that shows a directional needle pointing toward a [bearing]
/// (degrees clockwise from north, 0–360).
class CompassWidget extends StatefulWidget {
  /// Bearing in degrees (0 = North, 90 = East, 180 = South, 270 = West).
  final double bearing;

  /// Size (width and height) of the compass. Defaults to 220.
  final double size;

  const CompassWidget({
    super.key,
    required this.bearing,
    this.size = 220,
  });

  @override
  State<CompassWidget> createState() => _CompassWidgetState();
}

class _CompassWidgetState extends State<CompassWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousBearing = 0;

  @override
  void initState() {
    super.initState();
    _previousBearing = widget.bearing;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(CompassWidget old) {
    super.didUpdateWidget(old);
    if (old.bearing != widget.bearing) {
      _animation = Tween<double>(
        begin: _previousBearing,
        end: widget.bearing,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _previousBearing = widget.bearing;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => _CompassFace(
        bearing: _animation.value,
        size: widget.size,
      ),
    );
  }
}

class _CompassFace extends StatelessWidget {
  final double bearing;
  final double size;

  const _CompassFace({required this.bearing, required this.size});

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 10, spreadRadius: 2),
              ],
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3), width: 2),
            ),
          ),
          // Cardinal direction labels
          ..._cardinalLabels(radius),
          // Degree tick marks
          CustomPaint(
            size: Size(size, size),
            painter: _TickPainter(),
          ),
          // Direction arrow
          Transform.rotate(
            angle: bearing * pi / 180,
            child: CustomPaint(
              size: Size(size * 0.5, size * 0.5),
              painter: _ArrowPainter(),
            ),
          ),
          // Center dot
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          // Pet icon
          const Icon(Icons.pets, size: 18, color: Colors.white),
        ],
      ),
    );
  }

  List<Widget> _cardinalLabels(double radius) {
    const labels = ['N', 'E', 'S', 'W'];
    return labels.asMap().entries.map((e) {
      final angle = e.key * pi / 2;
      final labelRadius = radius * 0.72;
      return Positioned(
        left: radius + labelRadius * sin(angle) - 8,
        top: radius - labelRadius * cos(angle) - 10,
        child: Text(
          e.value,
          style: TextStyle(
            color: e.value == 'N' ? AppColors.error : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.16,
          ),
        ),
      );
    }).toList();
  }
}

class _TickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..strokeWidth = 1
      ..color = Colors.grey.shade300;
    final majorPaint = Paint()
      ..strokeWidth = 2
      ..color = Colors.grey.shade500;

    for (int i = 0; i < 72; i++) {
      final angle = i * 5 * pi / 180;
      final isMajor = i % 9 == 0;
      final tickLength = isMajor ? radius * 0.1 : radius * 0.05;
      final start = Offset(
        center.dx + (radius * 0.88) * cos(angle - pi / 2),
        center.dy + (radius * 0.88) * sin(angle - pi / 2),
      );
      final end = Offset(
        center.dx + (radius * 0.88 - tickLength) * cos(angle - pi / 2),
        center.dy + (radius * 0.88 - tickLength) * sin(angle - pi / 2),
      );
      canvas.drawLine(start, end, isMajor ? majorPaint : paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final arrowHeight = size.height * 0.95;

    // North half (red/primary)
    final northPath = Path()
      ..moveTo(center.dx, center.dy - arrowHeight / 2)
      ..lineTo(center.dx - size.width * 0.1, center.dy)
      ..lineTo(center.dx + size.width * 0.1, center.dy)
      ..close();

    // South half (grey)
    final southPath = Path()
      ..moveTo(center.dx, center.dy + arrowHeight / 2)
      ..lineTo(center.dx - size.width * 0.1, center.dy)
      ..lineTo(center.dx + size.width * 0.1, center.dy)
      ..close();

    canvas.drawPath(
        northPath, Paint()..color = AppColors.primary);
    canvas.drawPath(
        southPath, Paint()..color = Colors.grey.shade300);
  }

  @override
  bool shouldRepaint(_) => false;
}
