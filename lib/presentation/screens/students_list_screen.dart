import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/student_model.dart';
import '../../logic/providers/student_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/utils/whatsapp_helper.dart';
import '../../logic/providers/room_provider.dart';
import '../../logic/providers/rent_provider.dart';
import '../widgets/change_room_sheet.dart';
import '../widgets/student_profile_dialog.dart';
import '../widgets/common/premium_card.dart';
import '../widgets/common/compact_action_button.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/search_field.dart';

class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).loadStudents();
    });
  }

  void _showStudentProfile(BuildContext context, int studentId) {
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    final student = studentProvider.students.firstWhere((s) => s.id == studentId);

    showDialog(
      context: context,
      builder: (context) => StudentProfileDialog(student: student),
    );
  }

  Future<void> _deleteStudent(int studentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: const Text('Are you sure you want to delete this student? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Provider.of<StudentProvider>(context, listen: false).deleteStudent(studentId);

      if (mounted) {
        await Provider.of<RoomProvider>(context, listen: false).loadRooms();
        await Provider.of<RentProvider>(context, listen: false).loadStudents();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student deleted successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _callStudent(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendWhatsApp(String phone, String name) async {
    final success = await WhatsAppHelper.sendCustomMessage(phone, 'Hello $name!');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SearchField(
              hintText: 'Search by name, room, or contact...',
              onChanged: (value) =>
                  Provider.of<StudentProvider>(context, listen: false).searchStudents(value),
            ),
          ),
          Expanded(
            child: Consumer<StudentProvider>(
              builder: (context, studentProvider, _) {
                if (studentProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = studentProvider.students;

                if (students.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No students found',
                    subtitle: 'Try adjusting your search or filters',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildStudentCard(context, student),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, StudentModel student) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () => _showStudentProfile(context, student.id!),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.2),
              child: Text(
                student.name[0].toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryAccent,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Room ${student.roomNumber}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CompactActionButton(
                  icon: Icons.phone,
                  color: AppColors.successColor,
                  onPressed: () => _callStudent(student.contact),
                  tooltip: 'Call',
                ),
                const SizedBox(width: 6),
                CompactActionButton(
                  icon: Icons.message,
                  color: AppColors.primaryAccent,
                  onPressed: () => _sendWhatsApp(student.contact, student.name),
                  tooltip: 'WhatsApp',
                ),
                const SizedBox(width: 6),
                // Tapping the card already opens the profile, so the third slot
                // holds the less-common actions instead of a duplicate button.
                PopupMenuButton<String>(
                  tooltip: 'More actions',
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                  color: AppColors.cardBackground,
                  onSelected: (value) {
                    if (value == 'profile') {
                      _showStudentProfile(context, student.id!);
                    } else if (value == 'room') {
                      ChangeRoomSheet.show(context, student);
                    } else if (value == 'delete') {
                      _deleteStudent(student.id!);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(children: [
                        Icon(Icons.visibility, size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 10),
                        Text('View profile'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'room',
                      child: Row(children: [
                        Icon(Icons.swap_horiz, size: 18, color: AppColors.primaryAccent),
                        SizedBox(width: 10),
                        Text('Change room'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, size: 18, color: AppColors.errorColor),
                        SizedBox(width: 10),
                        Text('Delete student', style: TextStyle(color: AppColors.errorColor)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
