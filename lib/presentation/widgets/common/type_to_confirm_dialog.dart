import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

/// Confirmation for actions that cannot be undone and would be expensive to
/// trigger by accident — wiping a month's rent, overwriting the database.
///
/// A plain "Are you sure?" is one careless tap away from disaster, so this
/// asks for a specific word to be typed before the action button enables.
class TypeToConfirmDialog extends StatefulWidget {
  final String title;
  final String message;

  /// The word the user has to type, e.g. `START` or `OVERWRITE`.
  final String requiredWord;
  final String actionLabel;
  final IconData actionIcon;
  final Color actionColor;

  const TypeToConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.requiredWord,
    required this.actionLabel,
    this.actionIcon = Icons.check,
    this.actionColor = AppColors.errorColor,
  });

  @override
  State<TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<TypeToConfirmDialog> {
  final _controller = TextEditingController();

  bool get _matches =>
      _controller.text.trim().toUpperCase() == widget.requiredWord.toUpperCase();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: widget.actionColor),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.lg),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              children: [
                const TextSpan(text: 'Type '),
                TextSpan(
                  text: widget.requiredWord,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w700,
                    color: widget.actionColor,
                  ),
                ),
                const TextSpan(text: ' to confirm.'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: widget.requiredWord),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: widget.actionColor),
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          icon: Icon(widget.actionIcon),
          label: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
