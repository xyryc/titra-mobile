import 'package:flutter/material.dart';

import 'package:titra/core/theme/app_colors.dart';

/// Four-bar password strength indicator with label. Bar and label colors
/// change by level: weak (red) → fair (amber) → good (light green) → strong (primary).
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({
    super.key,
    required this.level,
    this.label,
  });

  /// 0–4 bars filled. 0 = none, 1 = weak, 2 = fair, 3 = good, 4 = strong.
  final int level;
  final String? label;

  /// Color for the filled bars and label at this level. Strongest (4) = primary.
  static Color colorForLevel(int level) {
    switch (level) {
      case 1:
        return AppColors.error;
      case 2:
        return AppColors.warning;
      case 3:
        return AppColors.primaryLight;
      case 4:
        return AppColors.primary;
      default:
        return AppColors.outlineLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fillColor = colorForLevel(level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(4, (i) {
            final filled = i < level;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                height: 4,
                decoration: BoxDecoration(
                  color: filled ? fillColor : AppColors.outlineLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label!.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: fillColor,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ],
    );
  }
}
