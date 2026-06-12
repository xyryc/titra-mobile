import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../data/onboarding_page_model.dart';
import '../widgets/onboarding_logo.dart';

/// Single onboarding slide: illustration (logo or Lottie), title, body.
class OnboardingPageContent extends StatelessWidget {
  const OnboardingPageContent({
    super.key,
    required this.page,
    this.pageIndex = 0,
  });

  final OnboardingPageModel page;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget illustration;
    final double spacing;
    if (pageIndex == 1) {
      illustration = SizedBox(
        height: 260,
        child: Lottie.asset(
          'asset/lottie/fingerprint.json',
          fit: BoxFit.contain,
          repeat: true,
        ),
      );
      spacing = 32;
    } else if (pageIndex == 2) {
      illustration = SizedBox(
        height: 260,
        child: Lottie.asset(
          'asset/lottie/call.json',
          fit: BoxFit.contain,
          repeat: true,
        ),
      );
      spacing = 28;
    } else {
      illustration = const OnboardingLogo(size: 120);
      spacing = 48;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          illustration,
          SizedBox(height: spacing),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1D1C),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF6B7370),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
