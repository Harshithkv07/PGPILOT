import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import 'animated_count.dart';

/// Shared icon + value + label stat column.
///
/// Consolidates what used to be re-implemented separately as `_StatItem`
/// (stats_panel), `_InfoItem` (room_details_dialog), and `_buildStatItem`
/// (rent_history_dialog).
class StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final bool compact;

  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 28.0 : 36.0;
    final valueFontSize = compact ? 20.0 : 28.0;
    final labelFontSize = compact ? 11.0 : 13.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: AppRadius.mdBorder,
          ),
          child: Icon(icon, size: iconSize, color: color),
        ),
        SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
        AnimatedCount(
          value: value,
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: valueFontSize,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: labelFontSize,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
