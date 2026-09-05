import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/room_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import 'common/premium_card.dart';
import 'common/stat_chip.dart';

class StatsPanel extends StatelessWidget {
  const StatsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, roomProvider, _) {
        final totalCapacity = roomProvider.getTotalCapacity();
        final totalOccupied = roomProvider.getTotalOccupied();
        final totalAvailable = roomProvider.getTotalAvailable();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            final items = [
              StatChip(
                icon: Icons.bed_rounded,
                label: 'Total Capacity',
                value: totalCapacity,
                color: AppColors.primaryAccent,
                compact: isMobile,
              ),
              StatChip(
                icon: Icons.people_alt_rounded,
                label: 'Occupied',
                value: totalOccupied,
                color: AppColors.roomPartial,
                compact: isMobile,
              ),
              StatChip(
                icon: Icons.hotel_rounded,
                label: 'Available',
                value: totalAvailable,
                color: AppColors.roomEmpty,
                compact: isMobile,
              ),
            ];

            return PremiumCard(
              padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
              child: isMobile
                  ? Column(
                      children: [
                        items[0],
                        const Divider(height: 28),
                        items[1],
                        const Divider(height: 28),
                        items[2],
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(child: items[0]),
                        const VerticalDivider(width: 32),
                        Expanded(child: items[1]),
                        const VerticalDivider(width: 32),
                        Expanded(child: items[2]),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}
