// widgets/app_floating_navbar.dart
// Flat floating bottom navigation bar with integrated Add action button and sliding selection indicator.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import '../services/update_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AppFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;

  const AppFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: UpdateService.hasUpdateAvailable,
      builder: (context, hasUpdate, _) {
        return Container(
          height: 76,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF141418),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.borderZinc,
              width: 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const itemCount = 4;
              final itemWidth = constraints.maxWidth / itemCount;
              final itemHeight = constraints.maxHeight;

              // Compute target slot for indicator:
              // Index 0 -> Slot 0 (Home)
              // Index 1 -> Slot 1 (Vault)
              // Index 2 -> Slot 3 (Settings)
              final targetSlot = currentIndex >= 2 ? 3 : currentIndex;

              return Stack(
                children: [
                  // Smooth Sliding Active Indicator Pill
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: targetSlot * itemWidth,
                    top: 0,
                    width: itemWidth,
                    height: itemHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceZinc,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.offWhite.withValues(alpha: 0.10),
                          width: 1,
                        ),
                      ),
                    ),
                  ),

                  // Navigation Items Row: Home | Vault | Add (+) | Settings
                  Row(
                    children: [
                      _NavItem(
                        icon: HugeIcons.strokeRoundedHome01,
                        label: 'Home',
                        isSelected: currentIndex == 0,
                        onTap: () => onTap(0),
                      ),
                      _NavItem(
                        icon: HugeIcons.strokeRoundedSearch01,
                        label: 'Vault',
                        isSelected: currentIndex == 1,
                        onTap: () => onTap(1),
                      ),
                      _AddNavItem(
                        onTap: onAddTap,
                      ),
                      _NavItem(
                        icon: HugeIcons.strokeRoundedSettings01,
                        label: 'Settings',
                        isSelected: currentIndex == 2,
                        hasBadge: hasUpdate,
                        onTap: () => onTap(2),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final dynamic icon;
  final String label;
  final bool isSelected;
  final bool hasBadge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.hasBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.expand(
          child: Tooltip(
            message: label,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  scale: isSelected ? 1.06 : 1.0,
                  child: AppIcon(
                    icon,
                    size: 30,
                    strokeWidth: isSelected ? 1.8 : 1.5,
                    color: isSelected ? Colors.white : AppColors.textMuted,
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    right: 8,
                    top: 6,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF141418), width: 1.2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddNavItem extends StatelessWidget {
  final VoidCallback onTap;

  const _AddNavItem({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox.expand(
          child: Tooltip(
            message: 'Add Item',
            child: Center(
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.orangeAccent,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: AppColors.orangeDark,
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: AppIcon(
                    HugeIcons.strokeRoundedAddCircle,
                    size: 28,
                    strokeWidth: 2.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
