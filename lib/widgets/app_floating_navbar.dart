// widgets/app_floating_navbar.dart
// Flat floating bottom navigation bar with sliding selection indicator.

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../services/update_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AppFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeAccent = Theme.of(context).colorScheme.primary;

    return ValueListenableBuilder<bool>(
      valueListenable: UpdateService.hasUpdateAvailable,
      builder: (context, hasUpdate, _) {
        return Container(
          height: 66,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF141418),
            borderRadius: BorderRadius.circular(24),
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

              return Stack(
                children: [
                  // Smooth Sliding Active Indicator Pill
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: currentIndex * itemWidth,
                    top: 0,
                    width: itemWidth,
                    height: itemHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.orangeContainer,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: activeAccent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  // Navigation Items Row
                  Row(
                    children: [
                      _NavItem(
                        icon: HugeIcons.strokeRoundedHome01,
                        label: 'Home',
                        isSelected: currentIndex == 0,
                        onTap: () => onTap(0),
                      ),
                      _NavItem(
                        icon: HugeIcons.strokeRoundedLock,
                        label: 'Vault',
                        isSelected: currentIndex == 1,
                        onTap: () => onTap(1),
                      ),
                      _NavItem(
                        icon: HugeIcons.strokeRoundedDice,
                        label: 'Generate',
                        isSelected: currentIndex == 2,
                        onTap: () => onTap(2),
                      ),
                      _NavItem(
                        icon: HugeIcons.strokeRoundedSettings01,
                        label: 'Settings',
                        isSelected: currentIndex == 3,
                        hasBadge: hasUpdate,
                        onTap: () => onTap(3),
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
                  scale: isSelected ? 1.1 : 1.0,
                  // Line icons tint cleanly: active = pure accent, inactive = muted.
                  child: AppIcon(
                    icon,
                    size: 28,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : AppColors.textMuted,
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    right: -5,
                    top: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF141418), width: 1.2),
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
