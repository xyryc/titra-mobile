import 'package:flutter/material.dart';

/// Application color palette based on brand colors #0EB587 and #3BCF85.
/// Use [AppColors.gradient] for button and accent gradients.
class AppColors {
  AppColors._();

  // --- Brand colors ---
  /// Teal / mint green — primary brand color.
  static const Color primary = Color(0xFF0EB587);

  /// Brighter green — secondary brand color.
  static const Color secondary = Color(0xFF3BCF85);

  // --- Primary shades ---
  static const Color primaryLight = Color(0xFF4DD4A8);
  static const Color primaryDark = Color(0xFF0A9A6E);

  // --- Secondary shades ---
  static const Color secondaryLight = Color(0xFF6DD9A8);
  static const Color secondaryDark = Color(0xFF2BA868);

  // --- Gradients (for buttons, cards, etc.) ---
  /// Gradient from primary (teal) to secondary (green). Use for buttons and accents.
  static const LinearGradient gradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Vertical gradient (top = primary, bottom = secondary).
  static const LinearGradient gradientVertical = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // --- Neutrals (light theme) ---
  static const Color backgroundLight = Color(0xFFF6F6F6);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color onBackgroundLight = Color(0xFF1A1D1C);
  static const Color onSurfaceLight = Color(0xFF1A1D1C);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color outlineLight = Color(0xFFE0E6E4);

  // --- Neutrals (dark theme) ---
  static const Color backgroundDark = Color(0xFF121514);
  static const Color black = Color(0xFF121514);
  static const Color surfaceDark = Color(0xFF1C211F);
  static const Color onBackgroundDark = Color(0xFFE8ECEA);
  static const Color onSurfaceDark = Color(0xFFE8ECEA);
  static const Color outlineDark = Color(0xFF3D4542);

  // --- Semantic ---
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFE57373);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
}
