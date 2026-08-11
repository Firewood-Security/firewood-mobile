// theme/app_3d_button.dart
// Modern 3D Tactile Gradient Button widget for Firewood Flutter app

import 'package:flutter/material.dart';
import 'app_theme.dart';

enum App3DButtonVariant {
  primary,   // Deep Orange 3D gradient (Normal / Primary actions)
  neon,      // Bright Neon Orange 3D gradient (Lock Vault / Special actions)
  danger,    // Rose Red 3D gradient (Delete / Erase / Destructive)
  success,   // Mint Green 3D gradient (Save / Confirm / Complete)
  secondary, // Soft Dark Zinc 3D gradient (Cancel / Back / Secondary)
  soft,      // Translucent tinted container button
  outline,   // Bordered soft button
}

class App3DButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final App3DButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final double height;
  final double fontSize;

  const App3DButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = App3DButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = false,
    this.height = 48,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;
    final activeAccent = Theme.of(context).colorScheme.primary;

    Gradient? gradient;
    Color borderColor;
    Color textColor;

    switch (variant) {
      case App3DButtonVariant.primary:
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF6F40), Color(0xFFE64A19)],
        );
        borderColor = activeAccent;
        textColor = Colors.white;
        break;

      case App3DButtonVariant.neon:
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF7043), Color(0xFFFF3D00)],
        );
        borderColor = const Color(0xFFFF5722);
        textColor = Colors.white;
        break;

      case App3DButtonVariant.danger:
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
        );
        borderColor = const Color(0xFFDC2626);
        textColor = Colors.white;
        break;

      case App3DButtonVariant.success:
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF22C55E), Color(0xFF15803D)],
        );
        borderColor = const Color(0xFF16A34A);
        textColor = Colors.white;
        break;

      case App3DButtonVariant.secondary:
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2A2E), Color(0xFF1D1D20)],
        );
        borderColor = AppColors.borderZinc;
        textColor = AppColors.offWhite;
        break;

      case App3DButtonVariant.soft:
        gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            activeAccent.withValues(alpha: 0.25),
            activeAccent.withValues(alpha: 0.12),
          ],
        );
        borderColor = activeAccent.withValues(alpha: 0.4);
        textColor = AppColors.orangeOnContainer;
        break;

      case App3DButtonVariant.outline:
        gradient = null;
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
          Icon(icon, size: fontSize + 4, color: textColor),
          const SizedBox(width: 8),
        ],
        Text(
          isLoading ? 'Loading...' : label,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
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
          gradient: isDisabled ? null : gradient,
          color: isDisabled
              ? AppColors.cardZinc
              : (gradient == null ? AppColors.surfaceZinc : null),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: isDisabled
              ? null
              : [
                  const BoxShadow(
                    color: Colors.black45,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
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
