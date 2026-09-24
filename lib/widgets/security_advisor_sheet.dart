// widgets/security_advisor_sheet.dart
// Bottom sheet listing per-item security findings from
// SecurityAdvisorEngine (the single source of truth). Tapping the dashboard
// Security Advisor card opens this sheet; tapping an issue opens the
// credential. Matte styling: flat fills, thin 1px borders, no glow.

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/item_type.dart';
import '../services/item_service.dart';
import '../services/mini_ml_advisor.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class SecurityAdvisorSheet {
  static Color colorForSeverity(SecuritySeverity severity) =>
      switch (severity) {
        SecuritySeverity.critical => AppColors.roseAccent,
        SecuritySeverity.warn => const Color(0xFFF59E0B),
        SecuritySeverity.info => AppColors.periwinkleAccent,
      };

  static String _groupLabel(SecurityTipCategory category) => switch (category) {
        SecurityTipCategory.weakPasswords => 'WEAK PASSWORD',
        SecurityTipCategory.reusedPasswords => 'REUSED PASSWORD',
        SecurityTipCategory.missing2FA => 'MISSING 2FA',
        SecurityTipCategory.staleCredentials => 'STALE CREDENTIAL',
        SecurityTipCategory.backupDisabled => 'BACKUP',
        SecurityTipCategory.optimalHealth => 'HEALTH',
      };

  static dynamic _iconFor(DecryptedItem item) {
    switch (ItemTypeExt.fromString(item.type)) {
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

  static Future<void> show(
    BuildContext context, {
    required SecretKey key,
    required List<DecryptedItem> items,
    required Future<void> Function(SecretKey key, DecryptedItem item)
        onOpenItem,
  }) {
    HapticFeedback.lightImpact();
    final advisory = SecurityAdvisorEngine.analyze(items);

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceZinc,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppColors.borderZinc, width: 1),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderZinc,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header: title + score + issue count
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'SECURITY ADVISOR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AppColors.offWhite,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: advisory.securityScore >= 80
                          ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: advisory.securityScore >= 80
                            ? const Color(0xFF22C55E).withValues(alpha: 0.4)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${advisory.securityScore}%',
                      style: TextStyle(
                        fontFamily: 'Monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: advisory.securityScore >= 80
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.cardZinc,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderZinc),
                    ),
                    child: Text(
                      advisory.allClear
                          ? 'All clear'
                          : '${advisory.issueCount} issue${advisory.issueCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Compact plain-text metrics (no boxed chips)
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _Metric(
                      label: 'Strong',
                      value: advisory.strongCount,
                      color: const Color(0xFF22C55E)),
                  _Metric(
                      label: 'Weak',
                      value: advisory.weakCount,
                      color: advisory.weakCount > 0
                          ? AppColors.roseAccent
                          : AppColors.textMuted),
                  _Metric(
                      label: 'Reused',
                      value: advisory.reusedCount,
                      color: advisory.reusedCount > 0
                          ? const Color(0xFFF59E0B)
                          : AppColors.textMuted),
                  _Metric(
                      label: '2FA',
                      value: '${advisory.totpCoveragePercent.round()}%',
                      color: AppColors.orangeAccent),
                ],
              ),
              const SizedBox(height: 12),
              if (advisory.allClear)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No weak, reused, stale, or 2FA-less credentials found.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final group in advisory.groups) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 2),
                          child: Text(
                            '${_groupLabel(group.category)} (${group.count})',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: colorForSeverity(group.severity),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            group.advice,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        for (final issue in group.issues)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.cardZinc,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderZinc),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onOpenItem(key, issue.item);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      AppIcon(
                                        _iconFor(issue.item),
                                        size: 26,
                                        color: colorForSeverity(issue.severity),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              issue.item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.offWhite,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              issue.detail,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const AppIcon(
                                        AppIcons.chevronRight,
                                        size: 16,
                                        color: AppColors.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: AppColors.textMuted,
            ),
          ),
          TextSpan(
            text: '$value',
            style: TextStyle(
              fontFamily: 'Monospace',
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
