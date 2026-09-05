import 'package:flutter/material.dart';
import '../../data/models/student_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/utils/whatsapp_helper.dart';
import 'common/info_row.dart';
import 'common/section_header.dart';
import 'common/premium_button.dart';
import 'rent_history_dialog.dart';
import 'edit_student_dialog.dart';

class StudentProfileDialog extends StatefulWidget {
  final StudentModel student;

  const StudentProfileDialog({
    super.key,
    required this.student,
  });

  @override
  State<StudentProfileDialog> createState() => _StudentProfileDialogState();
}

class _StudentProfileDialogState extends State<StudentProfileDialog> {
  late StudentModel _currentStudent;

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student;
  }

  Future<void> _sendWhatsAppMessage(String phone, String message) async {
    final success = await WhatsAppHelper.sendCustomMessage(phone, message);

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
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.2),
                  child: Text(
                    _currentStudent.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryAccent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentStudent.name,
                        style: const TextStyle(fontFamily: 'Sora', fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryAccent.withValues(alpha: 0.2),
                          borderRadius: AppRadius.smBorder,
                        ),
                        child: Text(
                          'Room ${_currentStudent.roomNumber}',
                          style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primaryAccent),
                  tooltip: 'Edit Student',
                  onPressed: () async {
                    final updatedStudent = await showDialog<StudentModel>(
                      context: context,
                      builder: (context) => EditStudentDialog(student: _currentStudent),
                    );

                    if (updatedStudent != null && mounted) {
                      setState(() {
                        _currentStudent = updatedStudent;
                      });
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Personal Information'),
                    const Divider(height: 24),
                    InfoRow(label: 'Date of Birth', value: _currentStudent.dob),
                    InfoRow(
                      label: 'Contact Number',
                      value: _currentStudent.contact,
                      actionIcon: Icons.message,
                      onAction: () => _sendWhatsAppMessage(_currentStudent.contact, 'Hello ${_currentStudent.name}!'),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionHeader(title: 'Family Information'),
                    const Divider(height: 24),
                    InfoRow(label: "Father's Name", value: _currentStudent.fatherName),
                    InfoRow(
                      label: "Father's Number",
                      value: _currentStudent.fatherNumber,
                      actionIcon: Icons.message,
                      onAction: () =>
                          _sendWhatsAppMessage(_currentStudent.fatherNumber, 'Hello, this is regarding ${_currentStudent.name}.'),
                    ),
                    InfoRow(label: "Mother's Name", value: _currentStudent.motherName),
                    InfoRow(
                      label: "Mother's Number",
                      value: _currentStudent.motherNumber,
                      actionIcon: Icons.message,
                      onAction: () =>
                          _sendWhatsAppMessage(_currentStudent.motherNumber, 'Hello, this is regarding ${_currentStudent.name}.'),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionHeader(title: 'Academic & PG Information'),
                    const Divider(height: 24),
                    InfoRow(label: 'College/Workplace', value: _currentStudent.college),
                    InfoRow(label: 'Hometown', value: _currentStudent.hometown),
                    InfoRow(label: 'Address', value: _currentStudent.address),
                    InfoRow(label: 'Advance Amount', value: '₹${_currentStudent.advanceAmount}'),
                    InfoRow(label: 'Aadhar Card', value: _currentStudent.aadharName != null ? 'Attached' : 'Pending'),
                    InfoRow(label: 'Student Picture', value: _currentStudent.studentPictureName != null ? 'Attached' : 'Pending'),
                    InfoRow(label: 'Rent Status', value: _currentStudent.rentStatus),
                    InfoRow(label: 'Payment Mode', value: _currentStudent.paymentMode),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PremiumButton(
              label: 'View Rent History',
              icon: Icons.history,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => RentHistoryDialog(student: _currentStudent),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
