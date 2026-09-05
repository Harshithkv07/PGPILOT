import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shared spacing, radius, and shadow tokens so every screen uses the same
/// visual rhythm instead of ad hoc magic numbers.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
  static BorderRadius get xlBorder => BorderRadius.circular(xl);
  static BorderRadius get xxlBorder => BorderRadius.circular(xxl);
}

class AppShadows {
  /// Soft ambient shadow used under most elevated surfaces.
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  /// Subtle gold glow for primary CTAs / highlighted cards.
  static List<BoxShadow> goldGlow = [
    BoxShadow(
      color: AppColors.primaryAccent.withValues(alpha: 0.25),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}
