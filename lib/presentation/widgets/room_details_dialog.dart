import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/room_config_model.dart';
import '../../data/models/student_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/utils/whatsapp_helper.dart';
import '../../logic/providers/room_provider.dart';
import 'change_room_sheet.dart';
import 'common/premium_card.dart';
import 'common/stat_chip.dart';
import 'common/empty_state.dart';

class RoomDetailsDialog extends StatefulWidget {
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
  State<RoomDetailsDialog> createState() => _RoomDetailsDialogState();
}

class _RoomDetailsDialogState extends State<RoomDetailsDialog> {
  late RoomConfigModel _room;

  bool _editing = false;
  bool _saving = false;
  String? _error;

  late final TextEditingController _capacityController;
  late final TextEditingController _priceController;
  late final TextEditingController _ebController;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _capacityController = TextEditingController(text: '${_room.capacity}');
    _priceController = TextEditingController(text: '${_room.price}');
    _ebController = TextEditingController(text: '${_room.ebBill}');
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _priceController.dispose();
    _ebController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _capacityController.text = '${_room.capacity}';
      _priceController.text = '${_room.price}';
      _ebController.text = '${_room.ebBill}';
      _error = null;
      _editing = true;
    });
  }

  /// Nudge the bed count with the +/- buttons, never below the number of
  /// students already living in the room.
  void _stepCapacity(int delta) {
    final current = int.tryParse(_capacityController.text.trim()) ?? _room.capacity;
    final next = current + delta;
    if (next < 1) return;
    setState(() {
      _capacityController.text = '$next';
      _error = null;
    });
  }

  Future<void> _save() async {
    final capacity = int.tryParse(_capacityController.text.trim());
    final price = int.tryParse(_priceController.text.trim());
    final ebBill = int.tryParse(_ebController.text.trim()) ?? 0;

    if (capacity == null || price == null) {
      setState(() => _error = 'Beds and rent must both be numbers.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final failure = await roomProvider.updateRoomDetails(
      roomNumber: _room.roomNumber,
      capacity: capacity,
      price: price,
      ebBill: ebBill,
    );

    if (!mounted) return;

    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure;
      });
      return;
    }

    setState(() {
      _room = _room.copyWith(capacity: capacity, price: price, ebBill: ebBill);
      _saving = false;
      _editing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room ${_room.roomNumber} updated — $capacity beds at ₹$price/month.'),
        backgroundColor: AppColors.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = _room.capacity - widget.occupancy;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 640),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                        'Room ${_room.roomNumber}',
                        style: const TextStyle(fontFamily: 'Sora', fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${_room.capacity}-Sharing • ₹${_room.price}/month'
                        '${_room.ebBill > 0 ? ' • ₹${_room.ebBill} EB' : ''}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (!_editing)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primaryAccent),
                    onPressed: _startEditing,
                    tooltip: 'Edit room size, rent and EB bill',
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            // The header stays put and the rest scrolls, so opening the edit
            // panel adds height instead of squeezing the occupant list.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_editing) _buildEditor() else _buildStats(available),
                    const SizedBox(height: AppSpacing.xl),
                    const Text(
                      'Current Occupants',
                      style: TextStyle(fontFamily: 'Sora', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    widget.students.isEmpty
                        ? const EmptyState(icon: Icons.person_off_outlined, title: 'No students in this room')
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: widget.students.length,
                            itemBuilder: (context, index) {
                              final student = widget.students[index];
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
                                            Text(student.name,
                                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                            Text(student.contact, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.swap_horiz, color: AppColors.primaryAccent),
                                        onPressed: () async {
                                          final moved = await ChangeRoomSheet.show(context, student);
                                          if (moved && context.mounted) Navigator.pop(context);
                                        },
                                        tooltip: 'Move to another room',
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(int available) {
    return PremiumCard(
      color: AppColors.secondaryBackground,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          StatChip(icon: Icons.bed, label: 'Capacity', value: _room.capacity, color: AppColors.primaryAccent, compact: true),
          StatChip(icon: Icons.people, label: 'Occupied', value: widget.occupancy, color: AppColors.roomPartial, compact: true),
          StatChip(
            icon: Icons.hotel,
            label: 'Available',
            value: available,
            color: available > 0 ? AppColors.roomEmpty : AppColors.roomFull,
            compact: true,
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return PremiumCard(
      color: AppColors.secondaryBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Room Size & Rent',
            style: TextStyle(fontFamily: 'Sora', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.primaryAccent,
                onPressed: _saving ? null : () => _stepCapacity(-1),
                tooltip: 'Remove a bed',
              ),
              Expanded(
                child: TextField(
                  controller: _capacityController,
                  enabled: !_saving,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() => _error = null),
                  decoration: const InputDecoration(
                    labelText: 'Beds (sharing)',
                    prefixIcon: Icon(Icons.bed),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primaryAccent,
                onPressed: _saving ? null : () => _stepCapacity(1),
                tooltip: 'Add a bed',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              '${widget.occupancy} student${widget.occupancy == 1 ? '' : 's'} living here — the room cannot be smaller than that.',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() => _error = null),
                  decoration: const InputDecoration(
                    labelText: 'Rent / month',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _ebController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() => _error = null),
                  decoration: const InputDecoration(
                    labelText: 'EB bill',
                    prefixIcon: Icon(Icons.bolt),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: const TextStyle(color: AppColors.errorColor, fontSize: 12)),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => setState(() => _editing = false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
