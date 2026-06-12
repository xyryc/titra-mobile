import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Illustration for "High Quality Calls & Media": network of profile avatars
/// with overlay icons (mic, video, padlock).
class CallsAndMediaIllustration extends StatelessWidget {
  const CallsAndMediaIllustration({super.key, this.size = 280});

  final double size;

  static const Color _cardBg = Color(0xFFE8F5F1); // light muted teal
  static const Color _dotColor = Color(0xFFB0BEC5);
  static const Color _avatarBg = Color(0xFF90A4AE);
  static const Color _iconCircleGray = Color(0xFFE0E6E4);
  static const Color _iconSquareBlue = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.85,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Rounded card with network
          Container(
            width: size,
            height: size * 0.78,
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                size: Size(size, size * 0.78),
                painter: _NetworkGraphPainter(
                  dotColor: _dotColor,
                  avatarColor: _avatarBg,
                ),
              ),
            ),
          ),
          // Left: circular mic (light gray)
          Positioned(
            left: size * 0.08,
            top: size * 0.32,
            child: _CircleIconButton(
              size: size * 0.18,
              backgroundColor: _iconCircleGray,
              icon: Icons.mic_rounded,
              iconColor: Colors.white,
            ),
          ),
          // Top right: square video (blue)
          Positioned(
            right: size * 0.1,
            top: size * 0.08,
            child: _SquareIconButton(
              size: size * 0.16,
              backgroundColor: _iconSquareBlue,
              icon: Icons.videocam_rounded,
              iconColor: Colors.white,
            ),
          ),
          // Bottom right: square padlock (blue)
          Positioned(
            right: size * 0.1,
            bottom: size * 0.08,
            child: _SquareIconButton(
              size: size * 0.16,
              backgroundColor: _iconSquareBlue,
              icon: Icons.lock_rounded,
              iconColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.size,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
  });

  final double size;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: size * 0.5),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.size,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
  });

  final double size;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: size * 0.55),
    );
  }
}

class _NetworkGraphPainter extends CustomPainter {
  _NetworkGraphPainter({required this.dotColor, required this.avatarColor});

  final Color dotColor;
  final Color avatarColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centers = [
      Offset(size.width * 0.5, size.height * 0.38),
      Offset(size.width * 0.22, size.height * 0.55),
      Offset(size.width * 0.78, size.height * 0.52),
      Offset(size.width * 0.35, size.height * 0.72),
      Offset(size.width * 0.65, size.height * 0.68),
    ];
    final radii = [size.width * 0.12, size.width * 0.09, size.width * 0.09, size.width * 0.08, size.width * 0.08];

    // Dotted connections: center to others
    final dashLength = 4.0;
    final gapLength = 5.0;
    final strokePaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 1; i < centers.length; i++) {
      _drawDashedLine(canvas, centers[0], centers[i], strokePaint, dashLength, gapLength);
    }
    _drawDashedLine(canvas, centers[1], centers[3], strokePaint, dashLength, gapLength);
    _drawDashedLine(canvas, centers[2], centers[4], strokePaint, dashLength, gapLength);

    // Avatar circles (diverse placeholder colors)
    final avatarColors = [
      const Color(0xFF8D6E63),
      const Color(0xFF5C6BC0),
      const Color(0xFF66BB6A),
      const Color(0xFFEF5350),
      const Color(0xFF42A5F5),
    ];
    for (int i = 0; i < centers.length; i++) {
      final fillPaint = Paint()..color = avatarColors[i];
      canvas.drawCircle(centers[i], radii[i], fillPaint);
      // Simple face hint: two dots for eyes
      final eyeY = centers[i].dy - radii[i] * 0.2;
      final eyeOffset = radii[i] * 0.35;
      final eyePaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(centers[i].dx - eyeOffset, eyeY), radii[i] * 0.15, eyePaint);
      canvas.drawCircle(Offset(centers[i].dx + eyeOffset, eyeY), radii[i] * 0.15, eyePaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint, double dashLength, double gapLength) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    final unitX = dx / length;
    final unitY = dy / length;
    final totalSegment = dashLength + gapLength;
    double distance = 0;
    while (distance < length) {
      final segmentEnd = (distance + dashLength).clamp(0.0, length);
      final path = Path()
        ..moveTo(start.dx + distance * unitX, start.dy + distance * unitY)
        ..lineTo(start.dx + segmentEnd * unitX, start.dy + segmentEnd * unitY);
      canvas.drawPath(path, paint);
      distance += totalSegment;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
