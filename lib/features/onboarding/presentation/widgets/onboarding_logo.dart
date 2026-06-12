import 'package:flutter/material.dart';

/// Logo on gradient rounded square for onboarding.
class OnboardingLogo extends StatelessWidget {
  const OnboardingLogo({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        'asset/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
