import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../data/models/room_config_model.dart';
import 'common/premium_card.dart';
import 'common/section_header.dart';

/// Donut chart summarizing room occupancy (Full / Partial / Empty) —
/// gives the dashboard a real data-visualization anchor instead of just
/// raw stat numbers.
class OccupancyChart extends StatelessWidget {
  final List<RoomConfigModel> rooms;
  final Map<String, int> occupancyMap;

  const OccupancyChart({super.key, required this.rooms, required this.occupancyMap});

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) return const SizedBox.shrink();

    int full = 0, partial = 0, empty = 0;
    for (final room in rooms) {
      final occupied = occupancyMap[room.roomNumber] ?? 0;
      final available = room.capacity - occupied;
      if (available == 0) {
        full++;
      } else if (available < room.capacity) {
        partial++;
      } else {
        empty++;
      }
    }

    final total = full + partial + empty;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'ROOM OCCUPANCY', icon: Icons.donut_large_rounded),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 32,
                    sections: [
                      _section(full, total, AppColors.roomFull),
                      _section(partial, total, AppColors.roomPartial),
                      _section(empty, total, AppColors.roomEmpty),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow('Full', full, AppColors.roomFull),
                    const SizedBox(height: AppSpacing.sm),
                    _legendRow('Partial', partial, AppColors.roomPartial),
                    const SizedBox(height: AppSpacing.sm),
                    _legendRow('Empty', empty, AppColors.roomEmpty),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _section(int value, int total, Color color) {
    final pct = total == 0 ? 0.0 : value / total * 100;
    return PieChartSectionData(
      value: value == 0 ? 0.0001 : value.toDouble(),
      color: color,
      radius: 20,
      showTitle: false,
      badgeWidget: null,
      title: pct.toStringAsFixed(0),
    );
  }

  Widget _legendRow(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        Text(
          '$value',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
  }
}
