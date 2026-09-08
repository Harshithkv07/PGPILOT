import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/utils/backup_helper.dart';
import '../widgets/common/premium_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isProcessing = false;
  String _lastBackupDate = 'Never';

  @override
  void initState() {
    super.initState();
    _loadLastBackupDate();
  }

  Future<void> _loadLastBackupDate() async {
    try {
      final backupDirPath = await BackupHelper.getBackupDirectory();
      final backupDir = Directory(backupDirPath);
      if (await backupDir.exists()) {
        final List<FileSystemEntity> entities = await backupDir.list().toList();
        final List<File> backupFiles = entities.whereType<File>().where((f) => f.path.endsWith('.db')).toList();
        if (backupFiles.isNotEmpty) {
          backupFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          final lastBackup = backupFiles.first;
          final formatter = DateFormat('MMM dd, yyyy - hh:mm a');
          setState(() {
            _lastBackupDate = formatter.format(lastBackup.lastModifiedSync());
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading backup date: $e');
    }
  }

  Future<void> _handleExport() async {
    setState(() => _isProcessing = true);

    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Database Backup',
        fileName: BackupHelper.generateBackupFilename(),
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (outputFile != null) {
        if (!outputFile.endsWith('.db')) {
          outputFile += '.db';
        }

        final success = await BackupHelper.exportDatabase(outputFile);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Backup saved successfully!' : 'Backup failed.'),
              backgroundColor: success ? AppColors.successColor : AppColors.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        _loadLastBackupDate();
      }
    }
  }

  Future<void> _handleImport() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database', style: TextStyle(color: AppColors.errorColor)),
        content: const Text(
          'WARNING: Restoring a backup will permanently overwrite ALL current data in the application.\n\nAre you absolutely sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Overwrite Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Backup File to Restore',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result != null && result.files.single.path != null) {
        final success = await BackupHelper.importDatabase(result.files.single.path!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Database restored successfully! Please restart the app.' : 'Restore failed.'),
              backgroundColor: success ? AppColors.successColor : AppColors.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Data Management')),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryAccent.withValues(alpha: 0.1),
                                borderRadius: AppRadius.mdBorder,
                              ),
                              child: const Icon(Icons.cloud_upload, color: AppColors.primaryAccent, size: 32),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Database Backup',
                                    style: TextStyle(fontFamily: 'Sora', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Securely export your data to a .db file. You can use this file to restore your data on a new computer or after reinstalling the app.',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryBackground,
                            borderRadius: AppRadius.smBorder,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Last Automated Backup: $_lastBackupDate',
                                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 200,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _handleExport,
                            icon: const Icon(Icons.download),
                            label: const Text('Export Backup'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  PremiumCard(
                    padding: const EdgeInsets.all(24),
                    borderColor: AppColors.errorColor.withValues(alpha: 0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.errorColor.withValues(alpha: 0.1),
                                borderRadius: AppRadius.mdBorder,
                              ),
                              child: const Icon(Icons.restore, color: AppColors.errorColor, size: 32),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Restore Data',
                                    style: TextStyle(fontFamily: 'Sora', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Import a previously saved backup file. Warning: This will permanently overwrite all current data in the application.',
                                    style: TextStyle(color: AppColors.errorColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 200,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
                            onPressed: _handleImport,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Import Data'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
