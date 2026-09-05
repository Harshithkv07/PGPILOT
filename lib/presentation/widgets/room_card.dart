import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/room_config_model.dart';
import '../../logic/providers/student_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import 'room_details_dialog.dart';

class RoomCard extends StatefulWidget {
  final RoomConfigModel room;
  final int occupancy;

  const RoomCard({
    super.key,
    required this.room,
    required this.occupancy,
  });

  @override
  State<RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<RoomCard> {
  bool _pressed = false;

  Color _getStatusColor() {
    final available = widget.room.capacity - widget.occupancy;
    if (available == 0) return AppColors.roomFull;
    if (available < widget.room.capacity) return AppColors.roomPartial;
    return AppColors.roomEmpty;
  }

  String _getStatusText() {
    final available = widget.room.capacity - widget.occupancy;
    if (available == 0) return 'FULL';
    if (available < widget.room.capacity) return 'PARTIAL';
    return 'EMPTY';
  }

  void _showRoomDetails(BuildContext context) async {
    final students = await Provider.of<StudentProvider>(context, listen: false)
        .getStudentsByRoom(widget.room.roomNumber);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => RoomDetailsDialog(
          room: widget.room,
          students: students,
          occupancy: widget.occupancy,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final available = widget.room.capacity - widget.occupancy;
    final screenWidth = MediaQuery.of(context).size.width;

    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final cardPadding = isMobile ? 12.0 : (isTablet ? 14.0 : 16.0);
    final roomNumberFontSize = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);
    final bedsFontSize = isMobile ? 16.0 : (isTablet ? 17.0 : 18.0);
    final priceFontSize = isMobile ? 13.0 : 14.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => _showRoomDetails(context),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                statusColor.withValues(alpha: 0.22),
                AppColors.cardBackground,
              ],
            ),
            borderRadius: AppRadius.lgBorder,
            border: Border.all(color: statusColor.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16,
                    vertical: isMobile ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: AppRadius.mdBorder,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Room ${widget.room.roomNumber}',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: roomNumberFontSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: AppRadius.smBorder,
                  ),
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${widget.occupancy}/${widget.room.capacity} Beds',
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: bedsFontSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$available Available',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.currency_rupee,
                      size: isMobile ? 14 : 16,
                      color: AppColors.goldAccent,
                    ),
                    Flexible(
                      child: Text(
                        '${widget.room.price}/month',
                        style: TextStyle(
                          fontSize: priceFontSize,
                          color: AppColors.goldAccent,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
