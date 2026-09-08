import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

/// Gradient-glow CTA button — generalized from the pattern originally used
/// only on the welcome screen, now shared for primary actions app-wide.
class PremiumButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final Gradient gradient;
  final Color foregroundColor;

  const PremiumButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.height = 52,
    this.gradient = AppColors.goldGradient,
    this.foregroundColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || loading;
    // Disabled swaps the gold gradient for a dark grey fill, and the black
    // label that reads well on gold becomes near-invisible on it.
    final contentColor = isDisabled && !loading ? AppColors.textMuted : foregroundColor;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdBorder,
        gradient: isDisabled ? null : gradient,
        color: isDisabled ? AppColors.borderColor : null,
        boxShadow: isDisabled ? null : AppShadows.goldGlow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.mdBorder,
          onTap: isDisabled ? null : onPressed,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(foregroundColor),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 19, color: contentColor),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: contentColor,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
