import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/utils/backup_helper.dart';
import '../../logic/providers/auth_provider.dart';
import '../widgets/common/premium_card.dart';
import '../widgets/common/type_to_confirm_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isProcessing = false;
  String _lastBackupDate = 'Never';
  bool _usingDefaultPassword = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackupDate();
    _loadPasswordState();
  }

  Future<void> _loadPasswordState() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDefault = await auth.isUsingDefaultPassword();
    if (mounted) setState(() => _usingDefaultPassword = isDefault);
  }

  /// Change the login password. The app shipped with a fixed pair compiled
  /// into the binary; this lets the user replace it with one only they know.
  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.primaryAccent),
              SizedBox(width: 10),
              Expanded(child: Text('Change Password')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Current password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style: const TextStyle(color: AppColors.errorColor, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (newCtrl.text != confirmCtrl.text) {
                  setDialogState(() => error = 'The new passwords do not match.');
                  return;
                }
                final auth = Provider.of<AuthProvider>(ctx, listen: false);
                final failure = await auth.changeCredentials(
                  currentPassword: currentCtrl.text,
                  newPassword: newCtrl.text,
                );
                if (failure != null) {
                  setDialogState(() => error = failure);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.check),
              label: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();

    if (changed == true && mounted) {
      await _loadPasswordState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated.'),
          backgroundColor: AppColors.successColor,
        ),
      );
    }
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
    // Overwriting every record in the app was one tap on a red button away.
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => const TypeToConfirmDialog(
        title: 'Restore Database',
        message:
            'Restoring a backup permanently overwrites ALL current data — every student, '
            'room, payment and expense in the app.',
        requiredWord: 'OVERWRITE',
        actionLabel: 'Overwrite Data',
        actionIcon: Icons.restore,
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
                    borderColor: _usingDefaultPassword
                        ? AppColors.warningColor.withValues(alpha: 0.5)
                        : null,
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
                              child: const Icon(Icons.lock_outline,
                                  color: AppColors.primaryAccent, size: 32),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Login Password',
                                    style: TextStyle(
                                        fontFamily: 'Sora',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Your password is stored on this device as a salted hash, never as plain text.',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // The shipped password is inside the APK, so anyone
                        // with the file can read it. Say so, plainly.
                        if (_usingDefaultPassword) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.warningColor.withValues(alpha: 0.1),
                              borderRadius: AppRadius.smBorder,
                              border: Border.all(
                                  color: AppColors.warningColor.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: AppColors.warningColor, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'You are still using the password the app shipped with. '
                                    'It is visible to anyone who inspects the installer — set your own.',
                                    style: TextStyle(
                                        color: AppColors.warningColor, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 220,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _changePassword,
                            icon: const Icon(Icons.key),
                            label: const Text('Change Password'),
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
