import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

/// Standard elevated surface used across the app in place of raw
/// `Card`/`Container` combos — a subtle border, soft shadow, and consistent
/// radius so every screen reads as one cohesive system.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.gradient,
    this.borderColor,
    this.boxShadow,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.lgBorder;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.cardBackground) : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppColors.borderColorSubtle),
        boxShadow: boxShadow ?? AppShadows.soft,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}
