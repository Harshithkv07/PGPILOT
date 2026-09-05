import 'package:flutter/material.dart';
import '../../../core/constants/app_dimens.dart';

/// Small colored icon-in-a-box action button (call / WhatsApp / view etc).
class CompactActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String? tooltip;

  const CompactActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onPressed,
      borderRadius: AppRadius.smBorder,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: AppRadius.smBorder,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );

    if (tooltip != null) return Tooltip(message: tooltip, child: button);
    return button;
  }
}
