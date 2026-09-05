import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';

class NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavDestination({required this.icon, required this.activeIcon, required this.label});
}

/// Floating pill-style bottom navigation bar with an animated sliding
/// indicator behind the selected icon — replaces the stock
/// [BottomNavigationBar] for a more premium mobile/tablet feel.
class PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavDestination> destinations;

  const PremiumBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: AppRadius.xxlBorder,
          border: Border.all(color: AppColors.borderColorSubtle),
          boxShadow: AppShadows.soft,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / destinations.length;
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: itemWidth * currentIndex,
                  child: Container(
                    width: itemWidth,
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withValues(alpha: 0.16),
                        borderRadius: AppRadius.xlBorder,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(destinations.length, (index) {
                    final selected = index == currentIndex;
                    final dest = destinations[index];
                    return SizedBox(
                      width: itemWidth,
                      height: 68,
                      child: InkWell(
                        borderRadius: AppRadius.xlBorder,
                        onTap: () => onTap(index),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selected ? dest.activeIcon : dest.icon,
                              size: 22,
                              color: selected ? AppColors.primaryAccent : AppColors.textMuted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dest.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? AppColors.primaryAccent : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
