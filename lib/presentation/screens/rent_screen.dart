import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../logic/providers/rent_provider.dart';
import '../../logic/providers/room_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/utils/whatsapp_helper.dart';
import '../../data/models/student_model.dart';
import '../../data/services/file_storage_service.dart';
import '../../data/database/payment_history_repository.dart';
import '../widgets/common/premium_card.dart';
import '../widgets/common/premium_button.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/compact_action_button.dart';
import '../widgets/record_payment_dialog.dart';

class RentScreen extends StatefulWidget {
  const RentScreen({super.key});

  @override
  State<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends State<RentScreen> {
  final PaymentHistoryRepository _paymentHistoryRepository = PaymentHistoryRepository();
  final FileStorageService _fileStorageService = FileStorageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RentProvider>(context, listen: false).loadStudents();
      Provider.of<RoomProvider>(context, listen: false).loadRooms();
    });
  }

  /// Collects one instalment — any mix of cash and UPI — and adds it to what
  /// the student has already paid for the month.
  Future<void> _recordPayment(StudentModel student) async {
    final rentProvider = Provider.of<RentProvider>(context, listen: false);
    final amountDue = rentProvider.amountDueFor(student);

    final entry = await showDialog<PaymentEntry>(
      context: context,
      builder: (context) => RecordPaymentDialog(
        studentName: student.name,
        roomNumber: student.roomNumber,
        amountDue: amountDue,
        alreadyPaid: student.amountPaid,
      ),
    );

    if (entry == null || !mounted) return;

    String? screenshotPath;

    if (entry.hasUpi) {
      screenshotPath = await _pickUpiScreenshot(student);
      if (!mounted) return;
    }

    final newTotal = await rentProvider.recordPayment(
      studentId: student.id!,
      cashAmount: entry.cashAmount,
      upiAmount: entry.upiAmount,
      screenshotPath: screenshotPath,
    );

    if (!mounted) return;

    final settled = amountDue > 0 && newTotal >= amountDue;
    final remaining = (amountDue - newTotal).round();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(settled
            ? '₹${entry.total.round()} recorded — ${student.name}\'s rent is fully paid.'
            : '₹${entry.total.round()} recorded — ₹$remaining still due from ${student.name}.'),
        backgroundColor: settled ? AppColors.successColor : AppColors.warningColor,
      ),
    );
  }

  /// Optional proof for the UPI half of a payment. Returns null if the manager
  /// skipped it or the copy failed — the payment itself is still recorded.
  Future<String?> _pickUpiScreenshot(StudentModel student) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      dialogTitle: 'Select UPI Payment Screenshot (optional)',
    );

    if (result == null || result.files.single.path == null) return null;

    try {
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
      return await _fileStorageService.savePaymentScreenshot(
        sourcePath: result.files.single.path!,
        studentName: student.name,
        roomNumber: student.roomNumber,
        month: currentMonth,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving screenshot: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _revertToPending(StudentModel student) async {
    final paid = student.amountPaid.round();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear This Month\'s Payments'),
        content: Text(
          paid > 0
              ? 'This wipes the ₹$paid recorded against ${student.name} this month and puts them back to Pending. Continue?'
              : 'Put ${student.name} back to Pending for this month?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Provider.of<RentProvider>(context, listen: false).revertToPending(student.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payments cleared. Status reverted to pending.'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    }
  }

  Future<void> _viewCurrentMonthScreenshot(int studentId) async {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final payment = await _paymentHistoryRepository.getPaymentForMonth(studentId, currentMonth);

    if (payment == null || payment.screenshotPath == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No screenshot saved for this month.'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    await _fileStorageService.openScreenshot(payment.screenshotPath!);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening payment screenshot...'),
        backgroundColor: AppColors.primaryAccent,
      ),
    );
  }

  Future<void> _sendReminder(String contact, String name, String roomNumber, int amountDue) async {
    final success = await WhatsAppHelper.sendRentReminder(contact, name, roomNumber, amountDue);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Opening WhatsApp...'
              : 'Failed to open WhatsApp. Please check if WhatsApp is installed.'),
          backgroundColor: success ? AppColors.primaryAccent : AppColors.errorColor,
          duration: Duration(seconds: success ? 2 : 4),
        ),
      );
    }
  }

  Future<void> _startNewMonth() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Month'),
        content: const Text(
          'This archives the current month and resets every student to "Pending" with ₹0 paid. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryAccent, foregroundColor: Colors.black),
            child: const Text('Start New Month'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Provider.of<RentProvider>(context, listen: false).startNewMonth();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New month started! All statuses reset to pending.'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    }
  }

  /// One line of the revenue breakdown: colour dot, label, and amount.
  Widget _amountRow(String label, int amount, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Text(
          '₹$amount',
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return AppColors.paymentPaid;
      case 'Partial':
        return AppColors.warningColor;
      default:
        return AppColors.paymentPending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<RentProvider>(context, listen: false).loadStudents();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Revenue Tracker
              Consumer<RentProvider>(
                builder: (context, rentProvider, _) {
                  final collected = rentProvider.getCollectedRevenue();
                  final potential = rentProvider.getPotentialRevenue();
                  final pending = (potential - collected).clamp(0, potential);
                  final percentage = potential > 0 ? (collected / potential) : 0.0;

                  return PremiumCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monthly Revenue Tracker',
                          style: TextStyle(fontFamily: 'Sora', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: [
                            _CollectionRing(
                              collected: collected,
                              pending: pending,
                              percentage: percentage,
                            ),
                            const SizedBox(width: AppSpacing.xl),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _amountRow('Collected', collected, AppColors.successColor),
                                  const SizedBox(height: AppSpacing.md),
                                  _amountRow('Pending', pending, AppColors.paymentPending),
                                  const Divider(height: AppSpacing.xl),
                                  _amountRow('Potential', potential, AppColors.primaryAccent),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              PremiumButton(
                label: 'START NEW MONTH',
                icon: Icons.refresh,
                onPressed: _startNewMonth,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Rent Ledger
              Consumer2<RentProvider, RoomProvider>(
                builder: (context, rentProvider, roomProvider, _) {
                  if (rentProvider.isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final students = rentProvider.students;

                  if (students.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No students found',
                      ),
                    );
                  }

                  return Column(
                    children: students.map((student) {
                      final room = roomProvider.getRoomByNumber(student.roomNumber);
                      final amountDue = rentProvider.amountDueFor(student);
                      final ebShare = amountDue - (room?.price ?? amountDue);
                      final paid = student.amountPaid;
                      final remaining = rentProvider.amountRemainingFor(student);
                      final isPaid = student.rentStatus == 'Paid';
                      final isPartial = student.rentStatus == 'Partial';
                      final statusColor = _statusColor(student.rentStatus);
                      final progress =
                          amountDue > 0 ? (paid / amountDue).clamp(0.0, 1.0) : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PremiumCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.18),
                                    child: Text(
                                      student.name[0].toUpperCase(),
                                      style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, color: AppColors.primaryAccent),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(student.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14)),
                                        Text('Room ${student.roomNumber}',
                                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.16),
                                      borderRadius: AppRadius.smBorder,
                                    ),
                                    child: Text(
                                      student.rentStatus,
                                      style: TextStyle(fontWeight: FontWeight.w700, color: statusColor, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),

                              // Part payments only make sense against a visible
                              // running total, so show paid-of-due plus a bar.
                              if (paid > 0) ...[
                                Row(
                                  children: [
                                    Text(
                                      '₹${paid.round()}',
                                      style: TextStyle(
                                        fontFamily: 'Sora',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        color: isPaid ? AppColors.successColor : AppColors.warningColor,
                                      ),
                                    ),
                                    Text(
                                      ' of ₹$amountDue',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                    ),
                                    const Spacer(),
                                    if (remaining > 0)
                                      Text(
                                        '₹$remaining due',
                                        style: const TextStyle(fontSize: 12, color: AppColors.paymentPending),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    backgroundColor: AppColors.borderColor,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isPaid ? AppColors.successColor : AppColors.warningColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (paid == 0)
                                          Text('₹$amountDue',
                                              style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary)),
                                        if (ebShare > 0)
                                          Text('₹${room?.price ?? 0} + ₹$ebShare EB',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        if (student.paymentMode != '-')
                                          Text('via ${student.paymentMode}',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                  if (!isPaid) ...[
                                    CompactActionButton(
                                      icon: isPartial ? Icons.add_card : Icons.check_circle_outline,
                                      color: AppColors.successColor,
                                      tooltip: isPartial ? 'Record another payment' : 'Record payment',
                                      onPressed: () => _recordPayment(student),
                                    ),
                                    const SizedBox(width: 8),
                                    CompactActionButton(
                                      icon: Icons.message_outlined,
                                      color: AppColors.primaryAccent,
                                      tooltip: 'Send Reminder',
                                      onPressed: () => _sendReminder(
                                          student.contact, student.name, student.roomNumber, remaining > 0 ? remaining : amountDue),
                                    ),
                                    if (isPartial) ...[
                                      const SizedBox(width: 8),
                                      CompactActionButton(
                                        icon: Icons.undo_rounded,
                                        color: AppColors.errorColor,
                                        tooltip: 'Clear this month\'s payments',
                                        onPressed: () => _revertToPending(student),
                                      ),
                                    ],
                                  ] else ...[
                                    CompactActionButton(
                                      icon: Icons.undo_rounded,
                                      color: AppColors.errorColor,
                                      tooltip: 'Clear this month\'s payments',
                                      onPressed: () => _revertToPending(student),
                                    ),
                                    const SizedBox(width: 8),
                                    CompactActionButton(
                                      icon: Icons.image_outlined,
                                      color: AppColors.primaryAccent,
                                      tooltip: 'View screenshot for this month',
                                      onPressed: () => _viewCurrentMonthScreenshot(student.id!),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Donut gauge showing what share of this month's potential rent has actually
/// been collected, with the percentage called out in the middle.
class _CollectionRing extends StatelessWidget {
  final int collected;
  final int pending;
  final double percentage;

  const _CollectionRing({
    required this.collected,
    required this.pending,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = collected + pending > 0;

    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: hasData ? 2 : 0,
              centerSpaceRadius: 46,
              sections: hasData
                  ? [
                      PieChartSectionData(
                        value: collected.toDouble(),
                        color: AppColors.successColor,
                        radius: 14,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: pending.toDouble(),
                        color: AppColors.paymentPending.withValues(alpha: 0.85),
                        radius: 14,
                        showTitle: false,
                      ),
                    ]
                  : [
                      PieChartSectionData(
                        value: 1,
                        color: AppColors.borderColor,
                        radius: 14,
                        showTitle: false,
                      ),
                    ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(percentage * 100).round()}%',
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'collected',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
