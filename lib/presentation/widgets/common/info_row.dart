import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Label/value row with an optional trailing action icon (e.g. WhatsApp).
///
/// Formalizes the `_buildInfoRow` helper that previously lived only inside
/// student_profile_dialog.dart, so other dialogs can reuse it.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (actionIcon != null && onAction != null)
                  IconButton(
                    icon: Icon(actionIcon, size: 20, color: AppColors.primaryAccent),
                    onPressed: onAction,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
