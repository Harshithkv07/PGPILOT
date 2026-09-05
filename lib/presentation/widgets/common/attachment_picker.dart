import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

/// File-attachment control: shows an "attach" outline button when empty,
/// or a chip with the file name and a clear action once a file is picked.
///
/// Consolidates what used to be duplicated 4x (Aadhaar + photo, in both
/// add_student_screen.dart and edit_student_dialog.dart).
class AttachmentPicker extends StatelessWidget {
  final String label;
  final String? fileName;
  final IconData fileIcon;
  final IconData pickIcon;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const AttachmentPicker({
    super.key,
    required this.label,
    required this.fileName,
    required this.onPick,
    required this.onClear,
    this.fileIcon = Icons.description,
    this.pickIcon = Icons.attach_file,
  });

  @override
  Widget build(BuildContext context) {
    if (fileName != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: AppRadius.mdBorder,
          border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(fileIcon, color: AppColors.primaryAccent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                fileName!,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.clear, color: AppColors.errorColor),
              onPressed: onClear,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPick,
        icon: Icon(pickIcon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryAccent,
          side: const BorderSide(color: AppColors.primaryAccent),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
        ),
      ),
    );
  }
}
