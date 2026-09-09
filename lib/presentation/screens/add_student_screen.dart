import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/student_model.dart';
import '../../logic/providers/student_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/whatsapp_helper.dart';
import '../../logic/providers/room_provider.dart';
import '../../logic/providers/rent_provider.dart';
import '../../data/services/file_storage_service.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/attachment_picker.dart';
import '../widgets/common/premium_button.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _contactController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _fatherNumberController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _motherNumberController = TextEditingController();
  final _collegeController = TextEditingController();
  final _hometownController = TextEditingController();
  final _addressController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _advanceAmountController = TextEditingController();

  String? _aadharFilePath;
  String? _aadharFileName;

  String? _studentPictureFilePath;
  String? _studentPictureFileName;

  bool _isSaving = false;

  final FileStorageService _fileStorageService = FileStorageService();

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

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _dobController.clear();
    _contactController.clear();
    _fatherNameController.clear();
    _fatherNumberController.clear();
    _motherNameController.clear();
    _motherNumberController.clear();
    _collegeController.clear();
    _hometownController.clear();
    _addressController.clear();
    _roomNumberController.clear();
    _advanceAmountController.clear();
    setState(() {
      _aadharFilePath = null;
      _aadharFileName = null;
      _studentPictureFilePath = null;
      _studentPictureFileName = null;
    });
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? savedAadharName;
      String? aadharBase64;

      if (_aadharFilePath != null) {
        final roomNo = _roomNumberController.text.trim();
        final studentName = _nameController.text.trim();
        final savedFileMap = await _fileStorageService.saveAadharCard(
          sourcePath: _aadharFilePath!,
          studentName: studentName,
          roomNumber: roomNo,
        );
        savedAadharName = savedFileMap['name'];

        final bytes = await File(_aadharFilePath!).readAsBytes();
        aadharBase64 = base64Encode(bytes);
      }

      String? savedStudentPictureName;
      String? studentPictureBase64;

      if (_studentPictureFilePath != null) {
        final roomNo = _roomNumberController.text.trim();
        final studentName = _nameController.text.trim();
        final savedFileMap = await _fileStorageService.saveStudentPicture(
          sourcePath: _studentPictureFilePath!,
          studentName: studentName,
          roomNumber: roomNo,
        );
        savedStudentPictureName = savedFileMap['name'];

        final bytes = await File(_studentPictureFilePath!).readAsBytes();
        studentPictureBase64 = base64Encode(bytes);
      }

      final student = StudentModel(
        roomNumber: _roomNumberController.text.trim(),
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
        aadharCard: aadharBase64,
        aadharName: savedAadharName,
        studentPicture: studentPictureBase64,
        studentPictureName: savedStudentPictureName,
      );

      if (!mounted) return;
      final studentProvider = Provider.of<StudentProvider>(context, listen: false);
      final failure = await studentProvider.addStudent(student);
      final success = failure == null;

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        Provider.of<RoomProvider>(context, listen: false).loadRooms();
        Provider.of<RentProvider>(context, listen: false).loadStudents();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student added successfully!'),
            backgroundColor: AppColors.successColor,
          ),
        );

        final sendMessage = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Send Welcome Message?'),
            content: const Text('Do you want to send a WhatsApp welcome message to the student?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.chat),
                label: const Text('Yes'),
              ),
            ],
          ),
        );

        if (sendMessage == true) {
          await WhatsAppHelper.sendWelcomeMessage(
            student.contact,
            student.name,
            student.roomNumber,
          );
        }

        _clearForm();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving student: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Student'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
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
              const SizedBox(height: AppSpacing.xxl),
              Center(
                child: SizedBox(
                  width: 300,
                  child: PremiumButton(
                    label: 'SAVE STUDENT',
                    icon: Icons.save,
                    loading: _isSaving,
                    onPressed: _isSaving ? null : _saveStudent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Personal & Family Details', icon: Icons.badge_outlined),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Student Name *',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) => Validators.validateRequired(value, 'Student name'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dobController,
              decoration: const InputDecoration(
                labelText: 'Date of Birth (DD/MM/YYYY)',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: _selectDate,
              validator: Validators.validateOptionalDate,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Contact Number',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: Validators.validateOptionalPhone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fatherNameController,
              decoration: const InputDecoration(
                labelText: "Father's Name",
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fatherNumberController,
              decoration: const InputDecoration(
                labelText: "Father's Number",
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: Validators.validateOptionalPhone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _motherNameController,
              decoration: const InputDecoration(
                labelText: "Mother's Name",
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _motherNumberController,
              decoration: const InputDecoration(
                labelText: "Mother's Number",
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: Validators.validateOptionalPhone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightColumn() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Academic & PG Details', icon: Icons.school_outlined),
            const SizedBox(height: 20),
            TextFormField(
              controller: _collegeController,
              decoration: const InputDecoration(
                labelText: 'College/Workplace',
                prefixIcon: Icon(Icons.school),
              ),
              validator: null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hometownController,
              decoration: const InputDecoration(
                labelText: 'Hometown',
                prefixIcon: Icon(Icons.location_city),
              ),
              validator: null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Residence Address',
                prefixIcon: Icon(Icons.home),
              ),
              maxLines: 2,
              validator: null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _roomNumberController,
              decoration: const InputDecoration(
                labelText: 'Assign Room Number *',
                prefixIcon: Icon(Icons.meeting_room),
              ),
              
              validator: (value) => Validators.validateRequired(value, 'Room number'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _advanceAmountController,
              decoration: const InputDecoration(
                labelText: 'Advance Amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              // Money, so only digits get in — the column is free text and used
              // to accept anything, which made advances impossible to total.
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
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
        ),
      ),
    );
  }
}
