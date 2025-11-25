import 'package:flutter/material.dart';
import 'dart:math' as math;

class RadialLinesPainter extends CustomPainter {
  final double rotation;
  final int lineCount;

  RadialLinesPainter({required this.rotation, this.lineCount = 16});

  @override
  void paint(Canvas canvas, Size size) {
    // Center of the screen
    final center = Offset(size.width / 2, size.height / 2);
    // Radius large enough to cover the whole screen (diagonal half)
    final radius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;

    // Draw alternating colored sectors
    for (int i = 0; i < lineCount; i++) {
      final startAngle = (i / lineCount) * 2 * math.pi + rotation;
      final sweepAngle = (1 / lineCount) * 2 * math.pi;
      final isWhite = i % 2 == 0;

      final paint = Paint()
        ..color = isWhite ? Colors.white : Colors.yellow
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(startAngle) * radius,
          center.dy + math.sin(startAngle) * radius,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(RadialLinesPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
