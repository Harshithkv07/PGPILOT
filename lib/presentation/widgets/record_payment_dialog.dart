import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// What the manager entered in [RecordPaymentDialog]: how much of this
/// instalment came in as cash and how much over UPI.
class PaymentEntry {
  final double cashAmount;
  final double upiAmount;

  const PaymentEntry({required this.cashAmount, required this.upiAmount});

  double get total => cashAmount + upiAmount;
  bool get hasUpi => upiAmount > 0;
}

/// Collects one rent instalment, split between cash and UPI, so a student can
/// pay part now and the rest later. Returns a [PaymentEntry], or null if the
/// manager backed out.
class RecordPaymentDialog extends StatefulWidget {
  final String studentName;
  final String roomNumber;

  /// Full rent for the month, EB share included.
  final int amountDue;

  /// Already settled this month across earlier instalments.
  final double alreadyPaid;

  const RecordPaymentDialog({
    super.key,
    required this.studentName,
    required this.roomNumber,
    required this.amountDue,
    required this.alreadyPaid,
  });

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  final _cashController = TextEditingController();
  final _upiController = TextEditingController();
  String? _error;

  int get _remaining {
    final left = widget.amountDue - widget.alreadyPaid;
    return left > 0 ? left.round() : 0;
  }

  double get _cash => double.tryParse(_cashController.text.trim()) ?? 0;
  double get _upi => double.tryParse(_upiController.text.trim()) ?? 0;
  double get _entered => _cash + _upi;

  @override
  void dispose() {
    _cashController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  /// Drops the outstanding amount into one of the two fields and clears the
  /// other, for the common "paid it all in cash" / "all on UPI" case.
  void _fillRemaining(TextEditingController target, TextEditingController other) {
    setState(() {
      target.text = _remaining.toString();
      other.clear();
      _error = null;
    });
  }

  void _submit() {
    final cash = _cash;
    final upi = _upi;

    if (cash < 0 || upi < 0) {
      setState(() => _error = 'Amounts cannot be negative.');
      return;
    }
    if (cash + upi <= 0) {
      setState(() => _error = 'Enter a cash amount, a UPI amount, or both.');
      return;
    }
    if (_remaining > 0 && cash + upi > _remaining) {
      setState(() => _error =
          'That is more than the ₹$_remaining still due. Reduce the amount or revert the payment first.');
      return;
    }

    Navigator.pop(context, PaymentEntry(cashAmount: cash, upiAmount: upi));
  }

  @override
  Widget build(BuildContext context) {
    final settlesInFull = _entered > 0 && _entered >= _remaining;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Record Payment'),
          const SizedBox(height: 4),
          Text(
            '${widget.studentName} • Room ${widget.roomNumber}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: AppRadius.mdBorder,
                  border: Border.all(color: AppColors.borderColorSubtle),
                ),
                child: Column(
                  children: [
                    _summaryRow('Rent for this month', widget.amountDue.toDouble(),
                        AppColors.textPrimary),
                    if (widget.alreadyPaid > 0) ...[
                      const SizedBox(height: 6),
                      _summaryRow('Already paid', widget.alreadyPaid,
                          AppColors.successColor),
                    ],
                    const Divider(height: AppSpacing.lg),
                    _summaryRow(
                      'Still due',
                      _remaining.toDouble(),
                      _remaining > 0
                          ? AppColors.paymentPending
                          : AppColors.successColor,
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _amountField(
                controller: _cashController,
                label: 'Cash',
                icon: Icons.payments_outlined,
                color: AppColors.successColor,
                onFill: () => _fillRemaining(_cashController, _upiController),
              ),
              const SizedBox(height: AppSpacing.md),
              _amountField(
                controller: _upiController,
                label: 'UPI',
                icon: Icons.qr_code_2,
                color: AppColors.primaryAccent,
                onFill: () => _fillRemaining(_upiController, _cashController),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Text('Paying now',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(
                    '₹${_entered.round()}',
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_entered > 0) ...[
                const SizedBox(height: 6),
                Text(
                  settlesInFull
                      ? 'This clears the rent in full.'
                      : 'Part payment — ₹${(_remaining - _entered).round()} will still be due.',
                  style: TextStyle(
                    fontSize: 12,
                    color: settlesInFull
                        ? AppColors.successColor
                        : AppColors.warningColor,
                  ),
                ),
              ],
              if (_upi > 0) ...[
                const SizedBox(height: 6),
                const Text(
                  'You can attach the UPI screenshot after saving.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.errorColor, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: const Text('Save Payment'),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, double amount, Color color, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        Text(
          '₹${amount.round()}',
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: bold ? 16 : 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _amountField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onFill,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: '$label amount',
              prefixIcon: Icon(icon, color: color),
              prefixText: '₹ ',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          onPressed: _remaining > 0 ? onFill : null,
          child: const Text('All'),
        ),
      ],
    );
  }
}
