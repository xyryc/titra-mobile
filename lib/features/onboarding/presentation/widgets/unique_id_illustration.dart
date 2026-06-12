import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Central illustration for "Choose Your Unique ID" onboarding: dashed circles,
/// dark center with digital identity, ID badge, key and fingerprint icons.
class UniqueIdIllustration extends StatelessWidget {
  const UniqueIdIllustration({super.key, this.size = 280});

  final double size;

  static const Color _dashedColor = Color(0xFFE0E6E4);
  static const Color _centerDark = Color(0xFF2D3130);
  static const Color _badgeBg = Color(0xFFE8ECEA);
  static const Color _iconBg = Color(0xFFE8ECEA);
  static const Color _iconBlue = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DashedCirclesPainter(color: _dashedColor),
          ),
          // Dark center circle with person icon
          Container(
            width: size * 0.42,
            height: size * 0.42,
            decoration: const BoxDecoration(
              color: _centerDark,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              size: size * 0.22,
              color: const Color(0xFFB8860B), // golden-brown / digital identity
            ),
          ),
          // ID badge overlay at lower part of center circle
          Positioned(
            bottom: size * 0.18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _badgeBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '820 491 3321',
                style: TextStyle(
                  fontSize: size * 0.052,
                  fontWeight: FontWeight.w600,
                  color: _centerDark,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          // Key icon - left
          Positioned(
            left: size * 0.08,
            child: _IconBadge(icon: Icons.key_rounded, size: size),
          ),
          // Fingerprint icon - right
          Positioned(
            right: size * 0.08,
            child: _IconBadge(icon: Icons.fingerprint_rounded, size: size),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final boxSize = size * 0.18;
    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: UniqueIdIllustration._iconBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: UniqueIdIllustration._iconBlue, size: boxSize * 0.55),
    );
  }
}

class _DashedCirclesPainter extends CustomPainter {
  _DashedCirclesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = 2.0;
    final dashLength = 6.0;
    final gapLength = 4.0;

    for (int i = 1; i <= 3; i++) {
      final radius = (size.width / 2) * (0.35 + i * 0.2);
      _drawDashedCircle(canvas, center, radius, strokeWidth, dashLength, gapLength);
    }
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    double strokeWidth,
    double dashLength,
    double gapLength,
  ) {
    const totalDashes = 36;
    const sweepPerDash = (2 * math.pi) / totalDashes;
    final dashSweep = sweepPerDash * (dashLength / (dashLength + gapLength));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < totalDashes; i++) {
      final startAngle = i * sweepPerDash;
      final path = Path()
        ..moveTo(
          center.dx + radius * math.cos(startAngle),
          center.dy + radius * math.sin(startAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          dashSweep,
          false,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
