import 'package:flutter/material.dart';

import 'package:titra/core/theme/app_colors.dart';

/// Three-dot page indicator. Active dot uses primary green, inactive use light grey.
class OnboardingPageIndicator extends StatelessWidget {
  const OnboardingPageIndicator({
    super.key,
    required this.pageCount,
    required this.currentPage,
  });

  final int pageCount;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == currentPage;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.outlineLight,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
