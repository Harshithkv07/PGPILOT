import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/room_provider.dart';
import '../../logic/providers/student_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../data/services/excel_service.dart';
import '../widgets/room_card.dart';
import '../widgets/stats_panel.dart';
import '../widgets/occupancy_chart.dart';
import '../widgets/price_manager_dialog.dart';
import '../widgets/common/empty_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Calculate grid columns based on screen width
  int _getGridColumns(double width) {
    if (width < 600) return 1; // Mobile
    if (width < 900) return 2; // Tablet portrait
    if (width < 1200) return 3; // Tablet landscape
    return 4; // Desktop
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RoomProvider>(context, listen: false).loadRooms();
      Provider.of<StudentProvider>(context, listen: false).loadStudents();
    });
  }

  Future<void> _showAddRoomDialog() async {
    final roomNumberController = TextEditingController();
    final capacityController = TextEditingController();
    final priceController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Room'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: roomNumberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Room Number',
                    prefixIcon: Icon(Icons.meeting_room),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Beds (Capacity)',
                    prefixIcon: Icon(Icons.bed),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Rent per Month',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final roomText = roomNumberController.text.trim();
                final capacityText = capacityController.text.trim();
                final priceText = priceController.text.trim();

                // Room codes are free text so zero-padded codes like "0002"
                // are kept exactly as typed.
                final roomNumber = roomText;
                final capacity = int.tryParse(capacityText);
                final price = int.tryParse(priceText);

                if (roomNumber.isEmpty || capacity == null || price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a room number, and numeric beds and rent.'),
                      backgroundColor: AppColors.errorColor,
                    ),
                  );
                  return;
                }

                final roomProvider = Provider.of<RoomProvider>(context, listen: false);
                final success = await roomProvider.addRoom(
                  roomNumber: roomNumber,
                  capacity: capacity,
                  price: price,
                );

                if (!mounted) return;

                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Room $roomNumber added successfully.'
                          : 'Room $roomNumber already exists or could not be added.',
                    ),
                    backgroundColor: success ? AppColors.successColor : AppColors.errorColor,
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteRoomDialog() async {
    final roomNumberController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Room'),
          content: TextField(
            controller: roomNumberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Room Number',
              prefixIcon: Icon(Icons.meeting_room),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
              onPressed: () async {
                final roomNumber = roomNumberController.text.trim();

                if (roomNumber.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a room number.'),
                      backgroundColor: AppColors.errorColor,
                    ),
                  );
                  return;
                }

                final roomProvider = Provider.of<RoomProvider>(context, listen: false);
                final success = await roomProvider.deleteRoom(roomNumber);

                if (!mounted) return;

                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Room $roomNumber deleted successfully.'
                          : 'Cannot delete room $roomNumber. It may have students assigned or does not exist.',
                    ),
                    backgroundColor: success ? AppColors.successColor : AppColors.errorColor,
                  ),
                );
              },
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadExcel() async {
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);

    final students = studentProvider.students;
    final rooms = roomProvider.rooms;

    final roomsMap = {for (var room in rooms) room.roomNumber: room};

    final excelService = ExcelService();
    final filePath = await excelService.exportStudentsToExcel(students, roomsMap);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel file saved: $filePath'),
          backgroundColor: AppColors.successColor,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showPriceManager() {
    showDialog(context: context, builder: (context) => const PriceManagerDialog());
  }

  Future<void> _showResetEbBillsDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All EB Bills'),
        content: const Text('Are you sure you want to reset all EB bills to ₹0?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Provider.of<RoomProvider>(context, listen: false).resetAllEbBills();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All EB bills have been reset to ₹0'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<RoomProvider>(context, listen: false).loadRooms();
          await Provider.of<StudentProvider>(context, listen: false).loadStudents();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatsPanel(),
              const SizedBox(height: AppSpacing.lg),

              Consumer<RoomProvider>(
                builder: (context, roomProvider, _) {
                  if (roomProvider.isLoading) return const SizedBox.shrink();
                  return OccupancyChart(
                    rooms: roomProvider.allRooms,
                    occupancyMap: roomProvider.occupancyMap,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // Controls Row - Responsive
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // Filter Dropdown
                      Consumer<RoomProvider>(
                        builder: (context, roomProvider, _) {
                          return Container(
                            width: isMobile ? double.infinity : (isTablet ? constraints.maxWidth * 0.48 : 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: AppRadius.mdBorder,
                              border: Border.all(color: AppColors.borderColorSubtle),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: roomProvider.currentFilter,
                                isExpanded: true,
                                icon: const Icon(Icons.filter_list),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('Show All Rooms')),
                                  DropdownMenuItem(value: 'available', child: Text('Available Only')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    roomProvider.setFilter(value);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(
                        width: isMobile ? double.infinity : null,
                        child: ElevatedButton.icon(
                          onPressed: _showAddRoomDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Room'),
                        ),
                      ),

                      SizedBox(
                        width: isMobile ? double.infinity : null,
                        child: ElevatedButton.icon(
                          onPressed: _showDeleteRoomDialog,
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete Room'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.errorColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ),

                      SizedBox(
                        width: isMobile ? double.infinity : null,
                        child: ElevatedButton.icon(
                          onPressed: _showPriceManager,
                          icon: const Icon(Icons.attach_money),
                          label: const Text('Set Prices'),
                        ),
                      ),

                      SizedBox(
                        width: isMobile ? double.infinity : null,
                        child: ElevatedButton.icon(
                          onPressed: _downloadExcel,
                          icon: const Icon(Icons.download),
                          label: const Text('Excel'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.successColor),
                        ),
                      ),

                      SizedBox(
                        width: isMobile ? double.infinity : null,
                        child: ElevatedButton.icon(
                          onPressed: _showResetEbBillsDialog,
                          icon: const Icon(Icons.bolt),
                          label: const Text('Reset EB Bills'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warningColor, foregroundColor: Colors.black),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // Room Grid - Responsive
              Consumer<RoomProvider>(
                builder: (context, roomProvider, _) {
                  if (roomProvider.isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final rooms = roomProvider.rooms;

                  if (rooms.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: EmptyState(
                        icon: Icons.meeting_room_outlined,
                        title: 'No rooms found',
                        subtitle: 'Add your first room to get started.',
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = _getGridColumns(constraints.maxWidth);
                      final spacing = constraints.maxWidth < 600 ? 12.0 : 16.0;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: constraints.maxWidth < 600 ? 1.3 : 1.2,
                        ),
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          final occupancy = roomProvider.occupancyMap[room.roomNumber] ?? 0;
                          return RoomCard(room: room, occupancy: occupancy);
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
