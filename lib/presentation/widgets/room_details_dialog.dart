import 'package:flutter/material.dart';
import '../../data/models/room_config_model.dart';
import '../../data/models/student_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/utils/whatsapp_helper.dart';
import 'common/premium_card.dart';
import 'common/stat_chip.dart';
import 'common/empty_state.dart';

class RoomDetailsDialog extends StatelessWidget {
  final RoomConfigModel room;
  final List<StudentModel> students;
  final int occupancy;

  const RoomDetailsDialog({
    super.key,
    required this.room,
    required this.students,
    required this.occupancy,
  });

  @override
  Widget build(BuildContext context) {
    final available = room.capacity - occupancy;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withValues(alpha: 0.2),
                    borderRadius: AppRadius.mdBorder,
                  ),
                  child: const Icon(Icons.meeting_room, size: 32, color: AppColors.primaryAccent),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${room.roomNumber}',
                        style: const TextStyle(fontFamily: 'Sora', fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${room.capacity}-Sharing • ₹${room.price}/month',
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
            const SizedBox(height: AppSpacing.xl),
            PremiumCard(
              color: AppColors.secondaryBackground,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  StatChip(icon: Icons.bed, label: 'Capacity', value: room.capacity, color: AppColors.primaryAccent, compact: true),
                  StatChip(icon: Icons.people, label: 'Occupied', value: occupancy, color: AppColors.roomPartial, compact: true),
                  StatChip(
                    icon: Icons.hotel,
                    label: 'Available',
                    value: available,
                    color: available > 0 ? AppColors.roomEmpty : AppColors.roomFull,
                    compact: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Current Occupants',
              style: TextStyle(fontFamily: 'Sora', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: students.isEmpty
                  ? const EmptyState(icon: Icons.person_off_outlined, title: 'No students in this room')
                  : ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: PremiumCard(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.2),
                                  child: Text(
                                    student.name[0].toUpperCase(),
                                    style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(student.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                      Text(student.contact, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.message, color: AppColors.primaryAccent),
                                  onPressed: () {
                                    WhatsAppHelper.sendCustomMessage(student.contact, 'Hello ${student.name}!');
                                  },
                                  tooltip: 'Send WhatsApp Message',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
