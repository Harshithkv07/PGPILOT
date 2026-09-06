import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../data/services/student_import_service.dart';
import '../../logic/providers/room_provider.dart';
import '../../logic/providers/rent_provider.dart';
import '../../logic/providers/student_provider.dart';
import 'common/premium_button.dart';
import 'common/section_header.dart';

/// Pick a CSV of students, preview what was understood, then bulk-add them.
class ImportStudentsDialog extends StatefulWidget {
  const ImportStudentsDialog({super.key});

  @override
  State<ImportStudentsDialog> createState() => _ImportStudentsDialogState();
}

class _ImportStudentsDialogState extends State<ImportStudentsDialog> {
  final StudentImportService _service = StudentImportService();

  String? _fileName;
  ParsedCsv? _parsed;
  ImportResult? _result;
  bool _busy = false;
  String? _error;

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select students CSV',
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (picked == null || picked.files.single.path == null) {
        setState(() => _busy = false);
        return;
      }

      final parsed = await _service.parseFile(picked.files.single.path!);
      setState(() {
        _fileName = picked.files.single.name;
        _parsed = parsed;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not read that file: $e';
        _busy = false;
      });
    }
  }

  Future<void> _runImport() async {
    final parsed = _parsed;
    if (parsed == null || parsed.rows.isEmpty) return;

    setState(() => _busy = true);

    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    final result = await studentProvider.importStudents(parsed.rows);

    if (!mounted) return;

    // Rooms and rent totals both change when students land.
    await Provider.of<RoomProvider>(context, listen: false).loadRooms();
    if (!mounted) return;
    await Provider.of<RentProvider>(context, listen: false).loadStudents();

    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Import Students',
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(child: SingleChildScrollView(child: _buildBody())),
            const SizedBox(height: AppSpacing.lg),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_result != null) return _buildResult(_result!);
    if (_parsed != null) return _buildPreview(_parsed!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pick a CSV with one student per line — a name and a room number.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: AppRadius.mdBorder,
            border: Border.all(color: AppColors.borderColorSubtle),
          ),
          child: const Text(
            'Sl,Room,Name\n1,0002,First Student\n2,101,Second Student',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.6),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'The header row names the columns, so any extra ones (like a serial '
          'number) are ignored. Room codes keep their exact form — "0002" stays '
          '"0002". Rooms that don\'t exist yet are created for you, sized to fit; '
          'set their prices afterwards from Dashboard → Set Prices.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: const TextStyle(color: AppColors.errorColor)),
        ],
      ],
    );
  }

  Widget _buildPreview(ParsedCsv parsed) {
    final perRoom = <String, int>{};
    for (final r in parsed.rows) {
      perRoom[r.roomNumber] = (perRoom[r.roomNumber] ?? 0) + 1;
    }
    final rooms = perRoom.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _fileName ?? '',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${parsed.rows.length} students across ${rooms.length} rooms',
          style: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.successColor,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'PER ROOM'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: rooms
              .map((r) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent.withValues(alpha: 0.14),
                      borderRadius: AppRadius.smBorder,
                    ),
                    child: Text(
                      'Room $r · ${perRoom[r]}',
                      style: const TextStyle(color: AppColors.primaryAccent, fontSize: 12),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(title: 'FIRST FEW'),
        const SizedBox(height: AppSpacing.sm),
        ...parsed.rows.take(5).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${r.name}  →  Room ${r.roomNumber}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            )),
        if (parsed.problems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'LINES I COULD NOT READ'),
          const SizedBox(height: AppSpacing.sm),
          ...parsed.problems.take(8).map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Line ${p.lineNumber}: ${p.reason}',
                  style: const TextStyle(color: AppColors.errorColor, fontSize: 12),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildResult(ImportResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.successColor),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${result.added} students added',
              style: const TextStyle(
                fontFamily: 'Sora',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        if (result.roomsCreated.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Created ${result.roomsCreated.length} rooms: '
            '${result.roomsCreated.join(', ')}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Their prices are ₹0 — set them from Dashboard → Set Prices.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
        if (result.skipped.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'SKIPPED'),
          const SizedBox(height: AppSpacing.sm),
          ...result.skipped.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  s,
                  style: const TextStyle(color: AppColors.errorColor, fontSize: 12),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildActions() {
    if (_result != null) {
      return SizedBox(
        width: double.infinity,
        child: PremiumButton(
          label: 'DONE',
          icon: Icons.check,
          onPressed: () => Navigator.pop(context),
        ),
      );
    }

    if (_parsed != null) {
      final canImport = _parsed!.rows.isNotEmpty && !_busy;
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _pickFile,
              child: const Text('Choose another'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: PremiumButton(
              label: 'IMPORT',
              icon: Icons.download_done,
              loading: _busy,
              onPressed: canImport ? _runImport : null,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: PremiumButton(
        label: 'CHOOSE CSV FILE',
        icon: Icons.upload_file,
        loading: _busy,
        onPressed: _busy ? null : _pickFile,
      ),
    );
  }
}
