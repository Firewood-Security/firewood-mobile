// widgets/security_advisor_sheet.dart
// Bottom sheet listing per-item security issues. Tapping the dashboard
// Security Advisor card opens this sheet; tapping an issue opens the item.
// Matte styling: flat fills, thin 1px borders, no glow.

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/item_type.dart';
import '../services/item_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class AdvisorIssue {
  final String group;
  final DecryptedItem item;
  final String detail;
  final Color color;

  const AdvisorIssue({
    required this.group,
    required this.item,
    required this.detail,
    required this.color,
  });
}

class SecurityAdvisorSheet {
  static const _staleAfter = Duration(days: 120);

  /// Collects per-item issues using the same definitions as
  /// VaultAnalyticsService (weak = password < 8 chars; reuse = exact match;
  /// 2FA = totp_secret present; stale = untouched for 120+ days).
  static List<AdvisorIssue> collectIssues(
      List<DecryptedItem> items, DateTime now) {
    final issues = <AdvisorIssue>[];
    final logins = items
        .where((i) => ItemTypeExt.fromString(i.type) == ItemType.login)
        .toList();

    final passwordCounts = <String, int>{};
    for (final login in logins) {
      final pwd = login.fields['password']?.toString() ?? '';
      if (pwd.isNotEmpty) {
        passwordCounts[pwd] = (passwordCounts[pwd] ?? 0) + 1;
      }
    }

    for (final login in logins) {
      final pwd = login.fields['password']?.toString() ?? '';
      if (pwd.isNotEmpty && pwd.length < 8) {
        issues.add(AdvisorIssue(
          group: 'Weak password',
          item: login,
          detail: 'Password is shorter than 8 characters',
          color: AppColors.roseAccent,
        ));
      }
      if (pwd.isNotEmpty && (passwordCounts[pwd] ?? 0) > 1) {
        issues.add(AdvisorIssue(
          group: 'Reused password',
          item: login,
          detail:
              'Same password is used in ${passwordCounts[pwd]} credentials',
          color: AppColors.periwinkleAccent,
        ));
      }
      final totp = login.fields['totp_secret']?.toString() ?? '';
      if (totp.trim().isEmpty) {
        issues.add(AdvisorIssue(
          group: 'Missing 2FA',
          item: login,
          detail: 'No authenticator secret stored',
          color: AppColors.textMuted,
        ));
      }
    }

    for (final item in items) {
      if (now.difference(item.updatedAt) > _staleAfter) {
        final days = now.difference(item.updatedAt).inDays;
        issues.add(AdvisorIssue(
          group: 'Stale credential',
          item: item,
          detail: 'Not updated in $days days — consider rotation',
          color: AppColors.textMuted,
        ));
      }
    }

    return issues;
  }

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
    final issues = collectIssues(items, DateTime.now());
    final groups = <String, List<AdvisorIssue>>{};
    for (final issue in issues) {
      groups.putIfAbsent(issue.group, () => []).add(issue);
    }

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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.cardZinc,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderZinc),
                    ),
                    child: Text(
                      issues.isEmpty
                          ? 'All clear'
                          : '${issues.length} issue${issues.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (issues.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No weak, reused, stale, or 2FA-less credentials found.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 8, bottom: 6),
                          child: Text(
                            '${entry.key.toUpperCase()} (${entry.value.length})',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        for (final issue in entry.value)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.cardZinc,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.borderZinc),
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
                                        size: 22,
                                        color: issue.color,
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
                                              overflow:
                                                  TextOverflow.ellipsis,
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
                                                color:
                                                    AppColors.textMuted,
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
