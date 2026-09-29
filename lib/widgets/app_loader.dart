import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Standardized loading indicator for Firewood.
/// Can be used inline or as a modal dialog.
class AppLoader extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  final bool fullScreen;

  const AppLoader({
    super.key,
    this.message,
    this.size = 28,
    this.color,
    this.fullScreen = false,
  });

  /// Displays a modal loading barrier that prevents user interaction.
  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: AppColors.cardZinc,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderZinc, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.orangeAccent),
                  ),
                ),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.offWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Safely dismisses the loader dialog if active.
  static void hide(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.orangeAccent;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: size > 24 ? 2.8 : 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
          ),
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Center(child: content);
    }
    return content;
  }
}
