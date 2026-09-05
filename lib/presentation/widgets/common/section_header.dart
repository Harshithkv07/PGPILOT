import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Small caps-style section label used above form groups / card sections.
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.primaryAccent),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryAccent,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
