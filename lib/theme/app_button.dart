// theme/app_button.dart
// Matte flat button widget for Firewood — no gradients, no glows, no shadows.
// One-pixel borders, flat fills, subtle state changes only.

import 'package:flutter/material.dart';
import 'app_icons.dart';
import 'app_theme.dart';

enum AppButtonVariant {
  primary, // Flat accent fill (primary actions)
  neon, // Flat bright accent fill (lock / special actions)
  danger, // Flat red fill (destructive)
  success, // Flat green fill (confirm / complete)
  secondary, // Flat zinc fill (cancel / back)
  soft, // Flat tinted container fill
  outline, // Transparent with thin zinc border
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final dynamic icon;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final double height;
  final double fontSize;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = false,
    this.height = 48,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;

    late final Color background;
    late final Color borderColor;
    late final Color textColor;

    switch (variant) {
      case AppButtonVariant.primary:
        background = AppColors.pastelPrimaryFill;
        borderColor = AppColors.pastelPrimaryBorder;
        textColor = AppColors.pastelPrimaryText;
        break;
      case AppButtonVariant.neon:
        background = AppColors.pastelPrimaryFill;
        borderColor = AppColors.pastelPrimaryBorder;
        textColor = AppColors.pastelPrimaryText;
        break;
      case AppButtonVariant.danger:
        background = AppColors.pastelDangerFill;
        borderColor = AppColors.pastelDangerBorder;
        textColor = AppColors.pastelDangerText;
        break;
      case AppButtonVariant.success:
        background = AppColors.pastelSuccessFill;
        borderColor = AppColors.pastelSuccessBorder;
        textColor = AppColors.pastelSuccessText;
        break;
      case AppButtonVariant.secondary:
        background = AppColors.cardZinc;
        borderColor = AppColors.borderZinc;
        textColor = AppColors.offWhite;
        break;
      case AppButtonVariant.soft:
        background = AppColors.orangeContainer;
        borderColor = AppColors.orangeBorder;
        textColor = AppColors.orangeOnContainer;
        break;
      case AppButtonVariant.outline:
        background = Colors.transparent;
        borderColor = AppColors.borderZinc;
        textColor = AppColors.offWhite;
        break;
    }

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: textColor,
            ),
          )
        else if (icon != null) ...[
          AppIcon(icon, size: fontSize + 4, color: textColor),
          const SizedBox(width: 8),
        ],
        Text(
          isLoading ? 'Loading...' : label,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isDisabled ? 0.55 : 1.0,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isDisabled ? AppColors.cardZinc : background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled ? AppColors.borderZinc : borderColor,
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isDisabled ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}
