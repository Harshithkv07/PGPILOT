import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/room_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

class PriceManagerDialog extends StatefulWidget {
  const PriceManagerDialog({super.key});

  @override
  State<PriceManagerDialog> createState() => _PriceManagerDialogState();
}

class _PriceManagerDialogState extends State<PriceManagerDialog> {
  final _priceController = TextEditingController();
  final Set<String> _selectedRoomNumbers = {};
  int? _selectedCapacity;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _updateSingleRoom() async {
    if (_selectedRoomNumbers.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one room and enter a price'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    final newPrice = int.tryParse(_priceController.text);
    if (newPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    for (final roomNumber in _selectedRoomNumbers) {
      await roomProvider.updateRoomPrice(roomNumber, newPrice);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedRoomNumbers.length == 1
                ? 'Room price updated successfully'
                : 'Prices updated for ${_selectedRoomNumbers.length} rooms',
          ),
          backgroundColor: AppColors.successColor,
        ),
      );
    }
  }

  Future<void> _updateByCapacity() async {
    if (_selectedCapacity == null || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a capacity and enter a price'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    final newPrice = int.tryParse(_priceController.text);
    if (newPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    await Provider.of<RoomProvider>(context, listen: false).updatePriceByCapacity(_selectedCapacity!, newPrice);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All $_selectedCapacity-sharing rooms updated successfully'),
          backgroundColor: AppColors.successColor,
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
            const Text(
              'Price Manager',
              style: TextStyle(fontFamily: 'Sora', fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: Consumer<RoomProvider>(
                builder: (context, roomProvider, _) {
                  final rooms = roomProvider.rooms;

                  return ListView.separated(
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      final isSelected = _selectedRoomNumbers.contains(room.roomNumber);

                      return InkWell(
                        borderRadius: AppRadius.mdBorder,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedRoomNumbers.remove(room.roomNumber);
                            } else {
                              _selectedRoomNumbers.add(room.roomNumber);
                              _selectedCapacity = room.capacity;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryAccent.withValues(alpha: 0.1) : AppColors.cardBackground,
                            borderRadius: AppRadius.mdBorder,
                            border: Border.all(
                              color: isSelected ? AppColors.primaryAccent.withValues(alpha: 0.5) : AppColors.borderColorSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedRoomNumbers.add(room.roomNumber);
                                      _selectedCapacity = room.capacity;
                                    } else {
                                      _selectedRoomNumbers.remove(room.roomNumber);
                                    }
                                  });
                                },
                              ),
                              Expanded(
                                child: Text('Room ${room.roomNumber}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              ),
                              Text('${room.capacity}-Sharing', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              const SizedBox(width: 16),
                              Text('₹${room.price}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryAccent)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'New Price',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: _updateSingleRoom,
                  icon: const Icon(Icons.check),
                  label: const Text('Update Selected'),
                ),
                ElevatedButton.icon(
                  onPressed: _updateByCapacity,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentHighlight, foregroundColor: Colors.black),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Update All (Same Sharing)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
