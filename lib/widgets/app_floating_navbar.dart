// widgets/app_floating_navbar.dart
// Flat floating bottom navigation bar with sliding selection indicator.

import 'package:flutter/material.dart';
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
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.orangeBorder,
                          width: 1,
                        ),
                      ),
                    ),
                  ),

                  // Navigation Items Row
                  Row(
                    children: [
                      _NavItem(
                        icon: AppIcons.home,
                        activeIcon: AppIcons.homeFilled,
                        label: 'Home',
                        isSelected: currentIndex == 0,
                        onTap: () => onTap(0),
                      ),
                      _NavItem(
                        icon: AppIcons.vault,
                        activeIcon: AppIcons.vaultFilled,
                        label: 'Vault',
                        isSelected: currentIndex == 1,
                        onTap: () => onTap(1),
                      ),
                      _NavItem(
                        icon: AppIcons.generate,
                        activeIcon: AppIcons.generateFilled,
                        label: 'Generate',
                        isSelected: currentIndex == 2,
                        onTap: () => onTap(2),
                      ),
                      _NavItem(
                        icon: AppIcons.settings,
                        activeIcon: AppIcons.settingsFilled,
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
  final dynamic activeIcon;
  final String label;
  final bool isSelected;
  final bool hasBadge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    this.hasBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeAccent = Theme.of(context).colorScheme.primary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedScale(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    scale: isSelected ? 1.08 : 1.0,
                    // 3D asset icons carry their own color, so selection is
                    // expressed with opacity instead of tinting.
                    child: Opacity(
                      opacity: isSelected ? 1.0 : 0.45,
                      child: AppIcon(
                        isSelected ? activeIcon : icon,
                        size: 22,
                        color: isSelected ? activeAccent : AppColors.textMuted.withValues(alpha: 0.7),
                      ),
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
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textMuted.withValues(alpha: 0.75),
                  letterSpacing: isSelected ? -0.1 : 0,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
