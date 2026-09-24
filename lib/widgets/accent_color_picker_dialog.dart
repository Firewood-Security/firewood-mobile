import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/accent_color_service.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AccentColorPickerDialog extends StatelessWidget {
  const AccentColorPickerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => const AccentColorPickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.borderZinc,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIcon(
                          AppIcons.palette,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Accent Theme',
                                style: TextStyle(
                                  color: AppColors.offWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'App-wide highlight color',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: AppIcon(HugeIcons.strokeRoundedCancel01,
                              color: AppColors.textMuted, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ValueListenableBuilder<Color>(
                      valueListenable: AccentColorService.currentColor,
                      builder: (context, activeColor, _) {
                        return Column(
                          children: AccentColorService.presets.map((preset) {
                            final isSelected = activeColor.toARGB32() ==
                                preset.color.toARGB32();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.cardZinc
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? preset.color
                                      : AppColors.borderZinc,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    HapticFeedback.selectionClick();
                                    await AccentColorService.setAccentColor(
                                        preset);
                                    if (context.mounted)
                                      Navigator.of(context).pop();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        // Color Swatch
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: preset.color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.borderZinc,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                preset.name,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : AppColors.offWhite,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                preset.hex,
                                                style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 11,
                                                  fontFamily: 'Monospace',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? preset.color
                                                  : AppColors.borderZinc,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: isSelected
                                              ? Center(
                                                  child: Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      color: preset.color,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings tile component that triggers the AccentColorPickerDialog
class AccentColorPickerTile extends StatelessWidget {
  const AccentColorPickerTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AccentColorService.currentColor,
      builder: (context, activeColor, _) {
        final currentPreset = AccentColorService.presets.firstWhere(
          (p) => p.color.toARGB32() == activeColor.toARGB32(),
          orElse: () => AccentColorService.defaultAccent,
        );

        return ListTile(
          onTap: () => AccentColorPickerDialog.show(context),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderZinc, width: 1),
            ),
          ),
          title: const Text(
            'Accent Theme Color',
            style: TextStyle(
                color: AppColors.offWhite,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
          subtitle: Text(
            'Current: ${currentPreset.name} (${currentPreset.hex})',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceZinc,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderZinc),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentPreset.name,
                  style: TextStyle(
                    color: activeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                AppIcon(AppIcons.chevronDown,
                    color: AppColors.textMuted, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
