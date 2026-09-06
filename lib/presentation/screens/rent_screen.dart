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
import '../../data/services/file_storage_service.dart';
import '../../data/database/payment_history_repository.dart';
import '../widgets/common/premium_card.dart';
import '../widgets/common/premium_button.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/compact_action_button.dart';

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

  Future<void> _markAsPaid(int studentId, String studentName, String roomNumber) async {
    final paymentMode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How did the student pay?', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PremiumButton(
                    label: 'Cash',
                    icon: Icons.money,
                    gradient: LinearGradient(colors: [AppColors.successColor, AppColors.successColor]),
                    onPressed: () => Navigator.pop(context, 'Cash'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PremiumButton(
                    label: 'UPI',
                    icon: Icons.qr_code,
                    onPressed: () => Navigator.pop(context, 'UPI'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (paymentMode != null && mounted) {
      String? screenshotPath;

      if (paymentMode == 'UPI') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          dialogTitle: 'Select Payment Screenshot',
        );

        if (result != null && result.files.single.path != null) {
          try {
            final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

            screenshotPath = await _fileStorageService.savePaymentScreenshot(
              sourcePath: result.files.single.path!,
              studentName: studentName,
              roomNumber: roomNumber,
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
          }
        }
      }

      if (!mounted) return;
      await Provider.of<RentProvider>(context, listen: false)
          .markAsPaid(studentId, paymentMode, screenshotPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(screenshotPath != null
                ? 'Payment marked as paid with screenshot'
                : 'Payment marked as paid'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    }
  }

  Future<void> _revertToPending(int studentId, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revert Payment Status'),
        content: Text(
            'Are you sure you want to revert $studentName\'s payment status to Pending? This will delete the payment record for the current month.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revert'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Provider.of<RentProvider>(context, listen: false).revertToPending(studentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment status reverted to pending'),
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
          'This will reset all rent statuses to "Pending" and clear payment modes. Are you sure?',
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
              Consumer2<RentProvider, RoomProvider>(
                builder: (context, rentProvider, roomProvider, _) {
                  return FutureBuilder<List<int>>(
                    future: Future.wait([
                      rentProvider.getCollectedRevenue(),
                      rentProvider.getPotentialRevenue(),
                    ]),
                    builder: (context, snapshot) {
                      final collected = snapshot.data?[0] ?? 0;
                      final potential = snapshot.data?[1] ?? 0;
                      final pending = (potential - collected).clamp(0, potential == 0 ? 0 : potential);
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
                      final roomStudents = students.where((s) => s.roomNumber == student.roomNumber).length;
                      int ebShare = 0;
                      if (room != null && roomStudents > 0 && room.ebBill > 0) {
                        ebShare = (room.ebBill / roomStudents).round();
                      }
                      final amountDue = (room?.price ?? 0) + ebShare;
                      final isPaid = student.rentStatus == 'Paid';
                      final statusColor = isPaid ? AppColors.paymentPaid : AppColors.paymentPending;

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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('₹$amountDue',
                                            style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary)),
                                        if (ebShare > 0)
                                          Text('₹${room?.price ?? 0} + ₹$ebShare EB',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        if (!isPaid || student.paymentMode == '-')
                                          const SizedBox.shrink()
                                        else
                                          Text('via ${student.paymentMode}',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                  if (!isPaid) ...[
                                    CompactActionButton(
                                      icon: Icons.check_circle_outline,
                                      color: AppColors.successColor,
                                      tooltip: 'Mark as Paid',
                                      onPressed: () => _markAsPaid(student.id!, student.name, student.roomNumber),
                                    ),
                                    const SizedBox(width: 8),
                                    CompactActionButton(
                                      icon: Icons.message_outlined,
                                      color: AppColors.primaryAccent,
                                      tooltip: 'Send Reminder',
                                      onPressed: () => _sendReminder(student.contact, student.name, student.roomNumber, amountDue),
                                    ),
                                  ] else ...[
                                    CompactActionButton(
                                      icon: Icons.undo_rounded,
                                      color: AppColors.errorColor,
                                      tooltip: 'Revert to Pending',
                                      onPressed: () => _revertToPending(student.id!, student.name),
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
