import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/student_model.dart';
import '../../logic/providers/student_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/utils/validators.dart';
import '../../data/services/file_storage_service.dart';
import 'common/section_header.dart';
import 'common/attachment_picker.dart';
import 'common/premium_button.dart';

class EditStudentDialog extends StatefulWidget {
  final StudentModel student;

  const EditStudentDialog({super.key, required this.student});

  @override
  State<EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<EditStudentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _dobController;
  late TextEditingController _contactController;
  late TextEditingController _fatherNameController;
  late TextEditingController _fatherNumberController;
  late TextEditingController _motherNameController;
  late TextEditingController _motherNumberController;
  late TextEditingController _collegeController;
  late TextEditingController _hometownController;
  late TextEditingController _addressController;
  late TextEditingController _roomNumberController;
  late TextEditingController _advanceAmountController;

  String? _aadharFilePath;
  String? _aadharFileName;
  String? _existingAadharName;
  String? _existingAadharCard;

  String? _studentPictureFilePath;
  String? _studentPictureFileName;
  String? _existingStudentPictureName;
  String? _existingStudentPicture;

  bool _isSaving = false;

  final FileStorageService _fileStorageService = FileStorageService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.name);
    _dobController = TextEditingController(text: widget.student.dob);
    _contactController = TextEditingController(text: widget.student.contact);
    _fatherNameController = TextEditingController(text: widget.student.fatherName);
    _fatherNumberController = TextEditingController(text: widget.student.fatherNumber);
    _motherNameController = TextEditingController(text: widget.student.motherName);
    _motherNumberController = TextEditingController(text: widget.student.motherNumber);
    _collegeController = TextEditingController(text: widget.student.college);
    _hometownController = TextEditingController(text: widget.student.hometown);
    _addressController = TextEditingController(text: widget.student.address);
    _roomNumberController = TextEditingController(text: widget.student.roomNumber.toString());
    _advanceAmountController = TextEditingController(text: widget.student.advanceAmount);

    _existingAadharName = widget.student.aadharName;
    _existingAadharCard = widget.student.aadharCard;
    _aadharFileName = _existingAadharName;

    _existingStudentPictureName = widget.student.studentPictureName;
    _existingStudentPicture = widget.student.studentPicture;
    _studentPictureFileName = _existingStudentPictureName;
  }

  Future<void> _pickAadharCard() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _aadharFilePath = result.files.single.path;
          _aadharFileName = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking Aadhar card: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _contactController.dispose();
    _fatherNameController.dispose();
    _fatherNumberController.dispose();
    _motherNameController.dispose();
    _motherNumberController.dispose();
    _collegeController.dispose();
    _hometownController.dispose();
    _addressController.dispose();
    _roomNumberController.dispose();
    _advanceAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryAccent,
              surface: AppColors.cardBackground,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickStudentPicture() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _studentPictureFilePath = result.files.single.path;
          _studentPictureFileName = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking student picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _updateStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? finalAadharName = _aadharFileName;
      String? finalAadharCard = _existingAadharCard;

      if (_aadharFilePath != null) {
        final roomNo = int.parse(_roomNumberController.text);
        final studentName = _nameController.text.trim();
        final savedFileMap = await _fileStorageService.saveAadharCard(
          sourcePath: _aadharFilePath!,
          studentName: studentName,
          roomNumber: roomNo,
        );
        finalAadharName = savedFileMap['name'];

        final bytes = await File(_aadharFilePath!).readAsBytes();
        finalAadharCard = base64Encode(bytes);
      } else if (_aadharFileName == null && _existingAadharName != null) {
        await _fileStorageService.deleteAadharCard(_existingAadharName!);
        finalAadharCard = null;
      }

      String? finalStudentPictureName = _studentPictureFileName;
      String? finalStudentPicture = _existingStudentPicture;

      if (_studentPictureFilePath != null) {
        final roomNo = int.parse(_roomNumberController.text);
        final studentName = _nameController.text.trim();
        final savedFileMap = await _fileStorageService.saveStudentPicture(
          sourcePath: _studentPictureFilePath!,
          studentName: studentName,
          roomNumber: roomNo,
        );
        finalStudentPictureName = savedFileMap['name'];

        final bytes = await File(_studentPictureFilePath!).readAsBytes();
        finalStudentPicture = base64Encode(bytes);
      } else if (_studentPictureFileName == null && _existingStudentPictureName != null) {
        await _fileStorageService.deleteStudentPicture(_existingStudentPictureName!);
        finalStudentPicture = null;
      }

      final updatedStudent = StudentModel(
        id: widget.student.id,
        roomNumber: int.parse(_roomNumberController.text),
        name: _nameController.text.trim(),
        dob: _dobController.text.trim(),
        contact: _contactController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        fatherNumber: _fatherNumberController.text.trim(),
        motherName: _motherNameController.text.trim(),
        motherNumber: _motherNumberController.text.trim(),
        college: _collegeController.text.trim(),
        hometown: _hometownController.text.trim(),
        address: _addressController.text.trim(),
        advanceAmount: _advanceAmountController.text.trim(),
        rentStatus: widget.student.rentStatus,
        paymentMode: widget.student.paymentMode,
        aadharCard: finalAadharCard,
        aadharName: finalAadharName,
        studentPicture: finalStudentPicture,
        studentPictureName: finalStudentPictureName,
      );

      if (!mounted) return;
      final studentProvider = Provider.of<StudentProvider>(context, listen: false);
      await studentProvider.updateStudent(updatedStudent);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student data updated successfully!'),
          backgroundColor: AppColors.successColor,
        ),
      );
      Navigator.pop(context, updatedStudent);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating student: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Student Details',
                  style: TextStyle(fontFamily: 'Sora', fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 600) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildLeftColumn()),
                            const SizedBox(width: 24),
                            Expanded(child: _buildRightColumn()),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildLeftColumn(),
                            const SizedBox(height: 16),
                            _buildRightColumn(),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 200,
                  child: PremiumButton(
                    label: 'UPDATE DATA',
                    icon: Icons.save,
                    loading: _isSaving,
                    onPressed: _isSaving ? null : _updateStudent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Personal & Family Details'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Student Name *', prefixIcon: Icon(Icons.person)),
          validator: (value) => Validators.validateRequired(value, 'Student name'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _dobController,
          decoration: const InputDecoration(labelText: 'Date of Birth *', prefixIcon: Icon(Icons.calendar_today)),
          readOnly: true,
          onTap: _selectDate,
          validator: Validators.validateDate,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _contactController,
          decoration: const InputDecoration(labelText: 'Contact Number *', prefixIcon: Icon(Icons.phone)),
          keyboardType: TextInputType.phone,
          validator: Validators.validatePhone,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _fatherNameController,
          decoration: const InputDecoration(labelText: "Father's Name *", prefixIcon: Icon(Icons.person_outline)),
          validator: (value) => Validators.validateRequired(value, "Father's name"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _fatherNumberController,
          decoration: const InputDecoration(labelText: "Father's Number *", prefixIcon: Icon(Icons.phone_outlined)),
          keyboardType: TextInputType.phone,
          validator: Validators.validatePhone,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _motherNameController,
          decoration: const InputDecoration(labelText: "Mother's Name *", prefixIcon: Icon(Icons.person_outline)),
          validator: (value) => Validators.validateRequired(value, "Mother's name"),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _motherNumberController,
          decoration: const InputDecoration(labelText: "Mother's Number *", prefixIcon: Icon(Icons.phone_outlined)),
          keyboardType: TextInputType.phone,
          validator: Validators.validatePhone,
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Academic & PG Details'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _collegeController,
          decoration: const InputDecoration(labelText: 'College/Workplace *', prefixIcon: Icon(Icons.school)),
          validator: (value) => Validators.validateRequired(value, 'College/Workplace'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _hometownController,
          decoration: const InputDecoration(labelText: 'Hometown *', prefixIcon: Icon(Icons.location_city)),
          validator: (value) => Validators.validateRequired(value, 'Hometown'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(labelText: 'Residence Address *', prefixIcon: Icon(Icons.home)),
          maxLines: 2,
          validator: (value) => Validators.validateRequired(value, 'Address'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _roomNumberController,
          decoration: const InputDecoration(labelText: 'Room Number *', prefixIcon: Icon(Icons.meeting_room)),
          keyboardType: TextInputType.number,
          validator: (value) => Validators.validateNumber(value, 'Room number'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _advanceAmountController,
          decoration: const InputDecoration(labelText: 'Advance Amount *', prefixIcon: Icon(Icons.currency_rupee)),
          keyboardType: TextInputType.number,
          validator: (value) => Validators.validateRequired(value, 'Advance amount'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Aadhar Card Attachment'),
        const SizedBox(height: AppSpacing.sm),
        AttachmentPicker(
          label: 'ATTACH AADHAR CARD (PDF / IMAGE)',
          fileName: _aadharFileName,
          onPick: _pickAadharCard,
          onClear: () => setState(() {
            _aadharFilePath = null;
            _aadharFileName = null;
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'Student Picture Attachment'),
        const SizedBox(height: AppSpacing.sm),
        AttachmentPicker(
          label: 'ATTACH STUDENT PICTURE (IMAGE ONLY)',
          fileName: _studentPictureFileName,
          fileIcon: Icons.image,
          pickIcon: Icons.add_a_photo,
          onPick: _pickStudentPicture,
          onClear: () => setState(() {
            _studentPictureFilePath = null;
            _studentPictureFileName = null;
          }),
        ),
      ],
    );
  }
}
