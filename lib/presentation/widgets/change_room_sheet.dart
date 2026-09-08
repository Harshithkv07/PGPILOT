import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../data/models/room_config_model.dart';
import '../../data/models/student_model.dart';
import '../../logic/providers/rent_provider.dart';
import '../../logic/providers/room_provider.dart';
import '../../logic/providers/student_provider.dart';
import 'common/empty_state.dart';

/// Moves a student to another room without anyone having to type a room number
/// and hope it exists and has space.
///
/// Every room is listed with its live occupancy and rent. Rooms with a free bed
/// are tappable; full rooms stay visible but offer a swap with one of their
/// occupants instead, which is the usual way out when the PG is full.
class ChangeRoomSheet extends StatefulWidget {
  final StudentModel student;

  const ChangeRoomSheet({super.key, required this.student});

  /// Opens the sheet and returns true if the student actually moved.
  static Future<bool> show(BuildContext context, StudentModel student) async {
    final moved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeRoomSheet(student: student),
    );
    return moved ?? false;
  }

  @override
  State<ChangeRoomSheet> createState() => _ChangeRoomSheetState();
}

class _ChangeRoomSheetState extends State<ChangeRoomSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _occupancyOf(RoomProvider rooms, String roomNumber) =>
      rooms.occupancyMap[roomNumber] ?? 0;

  /// What one student in [room] pays, EB share included, assuming [occupants]
  /// people live there. Mirrors how the rent ledger computes a due.
  int _dueFor(RoomConfigModel room, int occupants) {
    final heads = occupants < 1 ? 1 : occupants;
    final ebShare = room.ebBill > 0 ? (room.ebBill / heads).round() : 0;
    return room.price + ebShare;
  }

  Future<void> _confirmAndMove(RoomConfigModel target, int occupancy) async {
    final rent = Provider.of<RentProvider>(context, listen: false);
    final currentDue = rent.amountDueFor(widget.student);
    // One more head in the destination once this student lands there.
    final newDue = _dueFor(target, occupancy + 1);
    final paid = widget.student.amountPaid;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.student.name,
              style: const TextStyle(
                  fontFamily: 'Sora', fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _roomPill('Room ${widget.student.roomNumber}', AppColors.textSecondary),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 18, color: AppColors.primaryAccent),
                ),
                _roomPill('Room ${target.roomNumber}', AppColors.primaryAccent),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Rent is recharged at the new room's rate, so say so plainly
            // before it silently changes what this student owes.
            if (newDue != currentDue) ...[
              _noteBox(
                icon: Icons.currency_rupee,
                color: AppColors.warningColor,
                text: 'Rent for this month changes from ₹$currentDue to ₹$newDue.',
              ),
              if (paid > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                _noteBox(
                  icon: Icons.info_outline,
                  color: paid >= newDue ? AppColors.successColor : AppColors.paymentPending,
                  text: paid >= newDue
                      ? '₹${paid.round()} already paid still covers it.'
                      : '₹${paid.round()} already paid — ₹${(newDue - paid).round()} will be due.',
                ),
              ],
            ] else
              _noteBox(
                icon: Icons.check_circle_outline,
                color: AppColors.successColor,
                text: 'Rent stays at ₹$newDue for this month.',
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Move'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _apply(() => Provider.of<StudentProvider>(context, listen: false)
        .moveStudent(widget.student.id!, target.roomNumber));
  }

  Future<void> _confirmAndSwap(RoomConfigModel target) async {
    final students = Provider.of<StudentProvider>(context, listen: false);
    final occupants = await students.getStudentsByRoom(target.roomNumber);
    if (!mounted || occupants.isEmpty) return;

    final partner = await showDialog<StudentModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Swap with whom in room ${target.roomNumber}?'),
        children: [
          for (final occupant in occupants)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, occupant),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.2),
                    child: Text(
                      occupant.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(occupant.name,
                        style: const TextStyle(color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );

    if (partner == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Swap Rooms'),
        content: Text(
          '${widget.student.name} moves to room ${partner.roomNumber}, '
          'and ${partner.name} moves to room ${widget.student.roomNumber}.\n\n'
          'Rent for both is recharged at their new room\'s rate.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Swap'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _apply(() => Provider.of<StudentProvider>(context, listen: false)
        .swapStudents(widget.student.id!, partner.id!));
  }

  /// Runs a move or swap, then refreshes the providers that show occupancy and
  /// rent so the dashboard and ledger agree immediately.
  Future<void> _apply(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final failure = await action();

    if (!mounted) return;
    if (failure != null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure), backgroundColor: AppColors.errorColor),
      );
      return;
    }

    await Provider.of<RoomProvider>(context, listen: false).loadRooms();
    if (!mounted) return;
    await Provider.of<RentProvider>(context, listen: false).loadStudents();

    if (!mounted) return;
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room updated.'), backgroundColor: AppColors.successColor),
    );
  }

  Widget _roomPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: AppRadius.smBorder,
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );

  Widget _noteBox({required IconData icon, required Color color, required String text}) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.smBorder,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(color: color, fontSize: 12)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz, color: AppColors.primaryAccent),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Change Room',
                            style: TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                          Text(
                            '${widget.student.name} · currently in room ${widget.student.roomNumber}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Find a room…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: Consumer<RoomProvider>(
                  builder: (context, rooms, _) {
                    final all = rooms.allRooms
                        .where((r) => r.roomNumber != widget.student.roomNumber)
                        .where((r) =>
                            _query.isEmpty ||
                            r.roomNumber.toLowerCase().contains(_query.toLowerCase()))
                        .toList();

                    if (all.isEmpty) {
                      return EmptyState(
                        icon: Icons.meeting_room_outlined,
                        title: _query.isEmpty
                            ? 'No other rooms yet'
                            : 'No room matches "$_query"',
                        subtitle: _query.isEmpty
                            ? 'Add another room on the Dashboard first.'
                            : null,
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: all.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _roomTile(all[index], _occupancyOf(rooms, all[index].roomNumber)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roomTile(RoomConfigModel room, int occupancy) {
    final free = room.capacity - occupancy;
    final isFull = free <= 0;
    final statusColor = isFull ? AppColors.roomFull : AppColors.roomEmpty;
    final due = _dueFor(room, isFull ? occupancy : occupancy + 1);

    return Opacity(
      opacity: _busy ? 0.6 : 1,
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: AppRadius.mdBorder,
        child: InkWell(
          borderRadius: AppRadius.mdBorder,
          onTap: _busy
              ? null
              : isFull
                  ? () => _confirmAndSwap(room)
                  : () => _confirmAndMove(room, occupancy),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdBorder,
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: AppRadius.smBorder,
                  ),
                  child: Icon(
                    isFull ? Icons.no_meeting_room : Icons.meeting_room,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${room.roomNumber}',
                        style: const TextStyle(
                            fontFamily: 'Sora',
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$occupancy/${room.capacity} beds · ₹$due/month',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.16),
                        borderRadius: AppRadius.smBorder,
                      ),
                      child: Text(
                        isFull ? 'FULL' : '$free free',
                        style: TextStyle(
                            color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFull ? 'Swap…' : 'Move here',
                      style: const TextStyle(color: AppColors.primaryAccent, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
