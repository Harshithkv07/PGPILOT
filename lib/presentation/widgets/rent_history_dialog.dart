import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/payment_history_model.dart';
import '../../data/models/student_model.dart';
import '../../data/database/payment_history_repository.dart';
import '../../data/services/file_storage_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import 'common/premium_card.dart';
import 'common/stat_chip.dart';
import 'common/empty_state.dart';

class RentHistoryDialog extends StatefulWidget {
  final StudentModel student;

  const RentHistoryDialog({super.key, required this.student});

  @override
  State<RentHistoryDialog> createState() => _RentHistoryDialogState();
}

class _RentHistoryDialogState extends State<RentHistoryDialog> {
  final PaymentHistoryRepository _paymentRepo = PaymentHistoryRepository();
  final FileStorageService _fileService = FileStorageService();
  List<PaymentHistoryModel> _paymentHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    setState(() => _isLoading = true);

    try {
      final history = await _paymentRepo.getStudentPaymentHistory(widget.student.id!);
      final completeHistory = _generateCompleteHistory(history);

      setState(() {
        _paymentHistory = completeHistory;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading payment history: $e');
      setState(() => _isLoading = false);
    }
  }

  List<PaymentHistoryModel> _generateCompleteHistory(List<PaymentHistoryModel> existingHistory) {
    final now = DateTime.now();
    final joiningDate = DateTime(now.year, 1, 1); // Assume joined in January for demo

    final months = <PaymentHistoryModel>[];
    var currentMonth = DateTime(joiningDate.year, joiningDate.month, 1);
    final today = DateTime(now.year, now.month, 1);

    while (currentMonth.isBefore(today) || currentMonth.isAtSameMomentAs(today)) {
      final monthStr = DateFormat('yyyy-MM').format(currentMonth);

      final matching = existingHistory.where((h) => h.month == monthStr);
      final existing = matching.isEmpty ? null : matching.first;

      if (existing != null) {
        months.add(existing);
      } else {
        months.add(PaymentHistoryModel(
          studentId: widget.student.id!,
          month: monthStr,
          paymentStatus: 'Pending',
          paymentMode: '-',
        ));
      }

      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    return months.reversed.toList();
  }

  Future<void> _viewScreenshot(String screenshotPath) async {
    await _fileService.openScreenshot(screenshotPath);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rent Payment History',
                        style: TextStyle(fontFamily: 'Sora', fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.student.name} - Room ${widget.student.roomNumber}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!_isLoading && _paymentHistory.isNotEmpty) _buildPaymentStats(),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _paymentHistory.isEmpty
                      ? const EmptyState(icon: Icons.history, title: 'No payment history found')
                      : ListView.builder(
                          itemCount: _paymentHistory.length,
                          itemBuilder: (context, index) {
                            final payment = _paymentHistory[index];
                            return _buildPaymentItem(payment);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStats() {
    final paid = _paymentHistory.where((p) => p.paymentStatus == 'Paid').length;
    final partial = _paymentHistory.where((p) => p.paymentStatus == 'Partial').length;
    final pending = _paymentHistory.where((p) => p.paymentStatus == 'Pending').length;
    final total = _paymentHistory.length;

    return PremiumCard(
      color: AppColors.secondaryBackground,
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 18,
                sections: [
                  PieChartSectionData(value: paid == 0 ? 0.0001 : paid.toDouble(), color: AppColors.successColor, showTitle: false, radius: 12),
                  PieChartSectionData(value: partial == 0 ? 0.0001 : partial.toDouble(), color: AppColors.warningColor, showTitle: false, radius: 12),
                  PieChartSectionData(value: pending == 0 ? 0.0001 : pending.toDouble(), color: AppColors.paymentPending, showTitle: false, radius: 12),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: StatChip(icon: Icons.calendar_month, label: 'Months', value: total, color: AppColors.primaryAccent, compact: true)),
          Expanded(child: StatChip(icon: Icons.check_circle, label: 'Paid', value: paid, color: AppColors.successColor, compact: true)),
          Expanded(child: StatChip(icon: Icons.timelapse, label: 'Partial', value: partial, color: AppColors.warningColor, compact: true)),
          Expanded(child: StatChip(icon: Icons.pending, label: 'Pending', value: pending, color: AppColors.paymentPending, compact: true)),
        ],
      ),
    );
  }

  /// One-line description of a month: how much landed, how it was paid, and
  /// what is still owed. Months archived before amounts were tracked fall back
  /// to the plain status.
  String _paymentSummary(PaymentHistoryModel payment) {
    if (!payment.hasAmountDetail) {
      switch (payment.paymentStatus) {
        case 'Paid':
          return 'Paid via ${payment.paymentMode}';
        case 'Partial':
          return 'Part paid via ${payment.paymentMode}';
        default:
          return 'Payment Pending';
      }
    }

    if (payment.paymentStatus == 'Pending' || payment.amountPaid == 0) {
      return 'Pending — ₹${payment.amountDue.round()} due';
    }

    final paid = '₹${payment.amountPaid.round()} via ${payment.paymentMode}';
    if (payment.amountRemaining > 0) {
      return '$paid • ₹${payment.amountRemaining.round()} still due';
    }
    return 'Paid $paid';
  }

  Widget _buildPaymentItem(PaymentHistoryModel payment) {
    final isPaid = payment.paymentStatus == 'Paid';
    final isPartial = payment.paymentStatus == 'Partial';
    final monthDate = DateFormat('yyyy-MM').parse(payment.month);
    final monthName = DateFormat('MMMM yyyy').format(monthDate);
    final statusColor = isPaid
        ? AppColors.successColor
        : (isPartial ? AppColors.warningColor : AppColors.paymentPending);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: AppRadius.smBorder,
              ),
              child: Icon(
                isPaid
                    ? Icons.check_circle
                    : (isPartial ? Icons.timelapse : Icons.pending),
                color: statusColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(monthName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(isPaid || isPartial ? Icons.payment : Icons.schedule,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _paymentSummary(payment),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  // Months settled in instalments show the cash/UPI split so
                  // the ledger explains where each rupee came from.
                  if (payment.hasAmountDetail && payment.cashAmount > 0 && payment.upiAmount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '₹${payment.cashAmount.round()} cash + ₹${payment.upiAmount.round()} UPI',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                  if (payment.paidDate != null) ...[
                    const SizedBox(height: 2),
                    Text('Paid on: ${payment.paidDate}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            if (payment.screenshotPath != null)
              IconButton(
                icon: const Icon(Icons.image, color: AppColors.primaryAccent),
                onPressed: () => _viewScreenshot(payment.screenshotPath!),
                tooltip: 'View Payment Screenshot',
              ),
          ],
        ),
      ),
    );
  }
}
