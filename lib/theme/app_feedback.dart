import 'package:flutter/material.dart';
import 'app_icons.dart';
import 'app_theme.dart';

enum ToastType { success, error, info, warning }

class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();

    Color accentColor;
    dynamic iconData;
    Color iconBg;

    switch (type) {
      case ToastType.success:
        accentColor = const Color(0xFF10B981);
        iconData = AppIcons.checkCircle;
        iconBg = const Color(0xFF10B981).withValues(alpha: 0.15);
        break;
      case ToastType.error:
        accentColor = const Color(0xFFF43F5E);
        iconData = AppIcons.alertCircle;
        iconBg = const Color(0xFFF43F5E).withValues(alpha: 0.15);
        break;
      case ToastType.warning:
        accentColor = const Color(0xFFF59E0B);
        iconData = AppIcons.alertCircle;
        iconBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        break;
      case ToastType.info:
        accentColor = Theme.of(context).colorScheme.primary;
        iconData = AppIcons.info;
        iconBg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);
        break;
    }

    scaffold.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 84),
        duration: duration,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF18181C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.borderZinc,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderZinc, width: 1),
                ),
                child: Center(child: AppIcon(iconData, color: accentColor, size: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.offWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppDialog {
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDanger = false,
    dynamic icon = AppIcons.info,
  }) {
    final primaryColor = isDanger ? const Color(0xFFEF4444) : Theme.of(context).colorScheme.primary;

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.surfaceZinc,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.borderZinc),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Center(child: AppIcon(icon, color: primaryColor, size: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.offWhite,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(cancelLabel),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: isDanger
                            ? AppColors.roseAccent
                            : Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(context).pop(true),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            child: Text(
                              confirmLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
