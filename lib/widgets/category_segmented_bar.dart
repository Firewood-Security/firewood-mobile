// widgets/category_segmented_bar.dart
// Seamless joined category selector bar for credential types (Login, Card, Identity, Note, API Key)
// Features zero-gap merged segments with greyed-out inactive and vibrant orange active states

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/item_type.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class CategorySegmentedBar extends StatelessWidget {
  final ItemType selectedType;
  final ValueChanged<ItemType> onSelected;

  const CategorySegmentedBar({
    super.key,
    required this.selectedType,
    required this.onSelected,
  });

  dynamic _getTypeIcon(ItemType type) {
    switch (type) {
      case ItemType.login:
        return AppIcons.categoryLogin;
      case ItemType.card:
        return AppIcons.categoryCard;
      case ItemType.identity:
        return AppIcons.categoryIdentity;
      case ItemType.note:
        return AppIcons.categoryNote;
      case ItemType.developerSecret:
        return AppIcons.key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAccent = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderZinc,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: ItemType.values.map((type) {
          final isSelected = selectedType == type;
          final isFirst = type == ItemType.values.first;
          final isLast = type == ItemType.values.last;

          return Expanded(
            child: Material(
              color: isSelected ? activeAccent : Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(type);
                },
                borderRadius: BorderRadius.horizontal(
                  left: isFirst ? const Radius.circular(12) : Radius.zero,
                  right: isLast ? const Radius.circular(12) : Radius.zero,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? activeAccent : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        _getTypeIcon(type),
                        size: 22,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textMuted.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textMuted.withValues(alpha: 0.75),
                          letterSpacing: isSelected ? -0.1 : 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
