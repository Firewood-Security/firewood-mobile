import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../services/lock_service.dart';
import '../theme/app_button.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_feedback.dart';

/// Standardized error view for Firewood.
/// Displays user-friendly error context with optional retry and copy diagnostics actions.
class AppErrorView extends ConsumerWidget {
  final String title;
  final dynamic error;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool compact;
  final bool showCopyButton;

  const AppErrorView({
    super.key,
    this.title = 'Something went wrong',
    this.error,
    this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.compact = false,
    this.showCopyButton = true,
  });

  String get _detailedMessage {
    if (message != null && message!.isNotEmpty) {
      return message!;
    }
    if (error != null) {
      return error.toString();
    }
    return 'An unexpected error occurred. Please try again.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.roseContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.roseBorder),
        ),
        child: Row(
          children: [
            const AppIcon(
              HugeIcons.strokeRoundedAlertCircle,
              color: AppColors.roseAccent,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _detailedMessage,
                style: const TextStyle(
                  color: AppColors.roseOnContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRetry,
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: AppColors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardZinc,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderZinc, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.roseContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.roseBorder),
                ),
                child: const Center(
                  child: AppIcon(
                    HugeIcons.strokeRoundedAlertCircle,
                    color: AppColors.roseAccent,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.offWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _detailedMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onRetry != null)
                    Flexible(
                      child: AppButton(
                        label: retryLabel,
                        icon: HugeIcons.strokeRoundedRefresh,
                        variant: AppButtonVariant.primary,
                        height: 42,
                        fontSize: 13,
                        onPressed: onRetry,
                      ),
                    ),
                  if (onRetry != null && showCopyButton)
                    const SizedBox(width: 10),
                  if (showCopyButton)
                    AppButton(
                      label: 'Copy Details',
                      icon: HugeIcons.strokeRoundedCopy01,
                      variant: AppButtonVariant.secondary,
                      height: 42,
                      fontSize: 13,
                      onPressed: () {
                        // V-017: diagnostics can embed paths/tokens — route
                        // through the canonical copy path (flag + TTL).
                        ref
                            .read(lockServiceProvider)
                            .copySecret(_detailedMessage);
                        HapticFeedback.selectionClick();
                        AppToast.show(
                          context,
                          message: 'Error details copied',
                          type: ToastType.info,
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
