// services/mini_ml_advisor.dart
// Single source of truth for on-device, zero-knowledge security findings.
//
// Folds the former decision-tree tip classifier, the dashboard analytics
// counters, and the per-item issue collector into one deterministic engine
// (Finding -> Requirement -> ADR-class QA change; see docs/MODULE_CATALOG.md).
// No network calls; passwords are inspected in RAM only and never persisted,
// logged, or exported. The "Compromised" metric was removed: with no breach
// corpus on-device it was a permanent 0 and false reassurance.

import 'package:shared_preferences/shared_preferences.dart';

import '../models/item_type.dart';
import 'item_service.dart';

// --- Model thresholds (single definitions; UI never re-derives these) ---

/// Passwords shorter than this are critical.
const int kWeakCriticalBelow = 8;

/// Passwords shorter than this (but >= critical) are warnings. Also the
/// "weak" boundary for scoring and metrics.
const int kWeakWarnBelow = 12;

/// Credentials untouched for this long are stale.
const int kStaleAfterDays = 120;

/// Below this many logins, missing 2FA is reported as an issue but carries no
/// security-score penalty (new vaults are not punished for early setup).
const int kTotpPenaltyMinLogins = 3;

enum SecurityTipCategory {
  weakPasswords,
  reusedPasswords,
  missing2FA,
  staleCredentials,
  backupDisabled,
  optimalHealth,
}

/// Issue severity. Groups and the card headline are ordered worst-first.
enum SecuritySeverity { critical, warn, info }

int severityRank(SecuritySeverity s) => switch (s) {
      SecuritySeverity.critical => 0,
      SecuritySeverity.warn => 1,
      SecuritySeverity.info => 2,
    };

class SecurityTip {
  final String title;
  final String message;
  final SecurityTipCategory category;
  final String actionLabel;

  SecurityTip({
    required this.title,
    required this.message,
    required this.category,
    required this.actionLabel,
  });
}

/// One affected credential inside a finding group.
class AdvisorIssue {
  final SecurityTipCategory category;
  final SecuritySeverity severity;
  final DecryptedItem item;
  final String detail;

  const AdvisorIssue({
    required this.category,
    required this.severity,
    required this.item,
    required this.detail,
  });
}

/// All issues of one category, with a headline and one-line advice.
class SecurityFindingGroup {
  final SecurityTipCategory category;
  final SecuritySeverity severity;
  final String headline;
  final String advice;
  final List<AdvisorIssue> issues;

  const SecurityFindingGroup({
    required this.category,
    required this.severity,
    required this.headline,
    required this.advice,
    required this.issues,
  });

  int get count => issues.length;
}

/// Everything the dashboard card, the sheet and the stat cards need, from a
/// single evaluation pass.
class VaultAdvisory {
  final DateTime evaluatedAt;
  final int totalItems;
  final int totalLogins;
  final int strongCount;
  final int weakCount;
  final int reusedCount;
  final int totpCount;
  final double totpCoveragePercent;
  final int securityScore;

  /// Worst-severity-first.
  final List<SecurityFindingGroup> groups;

  /// Folded decision-tree tip (most urgent single recommendation).
  final SecurityTip? topTip;

  const VaultAdvisory({
    required this.evaluatedAt,
    required this.totalItems,
    required this.totalLogins,
    required this.strongCount,
    required this.weakCount,
    required this.reusedCount,
    required this.totpCount,
    required this.totpCoveragePercent,
    required this.securityScore,
    required this.groups,
    required this.topTip,
  });

  int get issueCount => groups.fold(0, (sum, g) => sum + g.count);

  bool get allClear => issueCount == 0;

  SecurityFindingGroup? get topGroup =>
      groups.isEmpty ? null : groups.first;
}

class SecurityAdvisorEngine {
  /// Single evaluation pass: metrics, per-item findings, score, top tip.
  static VaultAdvisory analyze(List<DecryptedItem> items, {DateTime? now}) {
    final DateTime at = now ?? DateTime.now();

    if (items.isEmpty) {
      return VaultAdvisory(
        evaluatedAt: at,
        totalItems: 0,
        totalLogins: 0,
        strongCount: 0,
        weakCount: 0,
        reusedCount: 0,
        totpCount: 0,
        totpCoveragePercent: 0,
        securityScore: 100,
        groups: const [],
        topTip: null,
      );
    }

    final logins = items
        .where((i) => ItemTypeExt.fromString(i.type) == ItemType.login)
        .toList();

    if (logins.isEmpty) {
      // Stale detection still applies to non-login items.
      final stale = _staleIssues(items, at);
      final groups = _buildGroups(<SecurityFindingGroup>[]);
      return VaultAdvisory(
        evaluatedAt: at,
        totalItems: items.length,
        totalLogins: 0,
        strongCount: 0,
        weakCount: 0,
        reusedCount: 0,
        totpCount: 0,
        totpCoveragePercent: 0,
        securityScore: 100,
        groups: groups,
        topTip: _topTip(const [], 0),
      );
    }

    // ---- Pass 1: metrics + reuse indexes ----
    int strongCount = 0;
    int weakCount = 0;
    int totpCount = 0;
    final normalizedCounts = <String, int>{};

    for (final login in logins) {
      final pwd = login.fields['password']?.toString() ?? '';
      final totp = login.fields['totp_secret']?.toString() ?? '';
      if (totp.trim().isNotEmpty) totpCount++;

      if (pwd.isNotEmpty) {
        final key = pwd.trim().toLowerCase();
        normalizedCounts[key] = (normalizedCounts[key] ?? 0) + 1;

        final strong = pwd.length >= kWeakWarnBelow &&
            pwd.contains(RegExp(r'[A-Z]')) &&
            (pwd.contains(RegExp(r'[0-9]')) ||
                pwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')));
        if (strong) {
          strongCount++;
        }
        if (pwd.length < kWeakWarnBelow) weakCount++;
      }
    }

    int reusedCount = 0;
    for (final c in normalizedCounts.values) {
      if (c > 1) reusedCount += (c - 1);
    }

    // ---- Pass 2: per-item findings ----
    final weakIssues = <AdvisorIssue>[];
    final reuseIssues = <AdvisorIssue>[];
    final totpIssues = <AdvisorIssue>[];

    for (final login in logins) {
      final pwd = login.fields['password']?.toString() ?? '';
      final totp = login.fields['totp_secret']?.toString() ?? '';
      final title = login.title.trim().toLowerCase();

      // Weak / predictable passwords
      if (pwd.isNotEmpty) {
        if (pwd.length < kWeakCriticalBelow) {
          weakIssues.add(AdvisorIssue(
            category: SecurityTipCategory.weakPasswords,
            severity: SecuritySeverity.critical,
            item: login,
            detail: 'Only ${pwd.length} characters — minimum is $kWeakCriticalBelow',
          ));
        } else if (pwd.length < kWeakWarnBelow) {
          weakIssues.add(AdvisorIssue(
            category: SecurityTipCategory.weakPasswords,
            severity: SecuritySeverity.warn,
            item: login,
            detail: '${pwd.length} characters — $kWeakWarnBelow+ recommended',
          ));
        } else if (title.isNotEmpty && pwd.trim().toLowerCase() == title) {
          weakIssues.add(AdvisorIssue(
            category: SecurityTipCategory.weakPasswords,
            severity: SecuritySeverity.warn,
            item: login,
            detail: 'Password matches the account name',
          ));
        }
      }

      // Reuse (normalized: trim + case-insensitive)
      if (pwd.isNotEmpty) {
        final key = pwd.trim().toLowerCase();
        final shared = normalizedCounts[key] ?? 0;
        if (shared > 1) {
          reuseIssues.add(AdvisorIssue(
            category: SecurityTipCategory.reusedPasswords,
            severity: shared >= 3
                ? SecuritySeverity.critical
                : SecuritySeverity.warn,
            item: login,
            detail: 'Shared with $shared credentials',
          ));
        }
      }

      // Missing 2FA (reported; scored only at >= 3 logins)
      if (totp.trim().isEmpty) {
        totpIssues.add(AdvisorIssue(
          category: SecurityTipCategory.missing2FA,
          severity: SecuritySeverity.info,
          item: login,
          detail: 'No authenticator secret stored',
        ));
      }
    }

    final staleIssues = _staleIssues(items, at);

    // ---- Groups (worst severity first, biggest group first within tier) ----
    final groups = _buildGroups([
      if (weakIssues.isNotEmpty)
        SecurityFindingGroup(
          category: SecurityTipCategory.weakPasswords,
          severity: worstSeverity(weakIssues),
          headline: _plural(weakIssues.length, 'weak or predictable password'),
          advice: 'Generate unique passwords in the Generator tab.',
          issues: weakIssues,
        ),
      if (reuseIssues.isNotEmpty)
        SecurityFindingGroup(
          category: SecurityTipCategory.reusedPasswords,
          severity: worstSeverity(reuseIssues),
          headline: _plural(reuseIssues.length, 'reused password'),
          advice: 'One leaked site exposes every account sharing its password.',
          issues: reuseIssues,
        ),
      if (totpIssues.isNotEmpty)
        SecurityFindingGroup(
          category: SecurityTipCategory.missing2FA,
          severity: SecuritySeverity.info,
          headline: _plural(totpIssues.length, 'login without 2FA'),
          advice: 'Add TOTP secrets for the accounts that matter most.',
          issues: totpIssues,
        ),
      if (staleIssues.isNotEmpty)
        SecurityFindingGroup(
          category: SecurityTipCategory.staleCredentials,
          severity: SecuritySeverity.info,
          headline: _plural(staleIssues.length, 'stale credential'),
          advice: 'Rotate long-lived passwords every few months.',
          issues: staleIssues,
        ),
    ]);

    // ---- Score: weak 45, reuse 35, 2FA 20 (only at >= 3 logins) ----
    final weakRatio = weakCount / logins.length;
    final reuseRatio = reusedCount / logins.length;
    final missingTotpRatio = (logins.length - totpCount) / logins.length;
    var score = 100.0 -
        weakRatio * 45 -
        reuseRatio * 35 -
        (logins.length >= kTotpPenaltyMinLogins ? missingTotpRatio * 20 : 0);
    score = score.clamp(0.0, 100.0);

    return VaultAdvisory(
      evaluatedAt: at,
      totalItems: items.length,
      totalLogins: logins.length,
      strongCount: strongCount,
      weakCount: weakCount,
      reusedCount: reusedCount,
      totpCount: totpCount,
      totpCoveragePercent: (totpCount / logins.length) * 100,
      securityScore: score.round(),
      groups: groups,
      topTip: _topTip(groups, logins.length),
    );
  }

  static List<AdvisorIssue> _staleIssues(List<DecryptedItem> items, DateTime now) {
    final issues = <AdvisorIssue>[];
    for (final item in items) {
      final touched = item.updatedAt.isAfter(item.createdAt)
          ? item.updatedAt
          : item.createdAt;
      final age = now.difference(touched).inDays;
      if (age > kStaleAfterDays) {
        issues.add(AdvisorIssue(
          category: SecurityTipCategory.staleCredentials,
          severity: SecuritySeverity.info,
          item: item,
          detail: 'Not updated in $age days — consider rotation',
        ));
      }
    }
    return issues;
  }

  static List<SecurityFindingGroup> _buildGroups(
      List<SecurityFindingGroup> groups) {
    groups.sort((a, b) {
      final bySeverity = severityRank(a.severity).compareTo(severityRank(b.severity));
      return bySeverity != 0 ? bySeverity : b.count.compareTo(a.count);
    });
    return groups;
  }

  static SecuritySeverity worstSeverity(List<AdvisorIssue> issues) {
    var worst = SecuritySeverity.info;
    for (final issue in issues) {
      if (severityRank(issue.severity) < severityRank(worst)) worst = issue.severity;
    }
    return worst;
  }

  static String _plural(int n, String noun) =>
      n == 1 ? '1 $noun' : '$n ${noun}s';

  /// Folded decision tree: one urgent tip, worst-first, login-count-gated.
  static SecurityTip? _topTip(List<SecurityFindingGroup> groups, int totalLogins) {
    final byCategory = <SecurityTipCategory, SecurityFindingGroup>{
      for (final g in groups) g.category: g,
    };

    final weak = byCategory[SecurityTipCategory.weakPasswords];
    if (weak != null && weak.severity == SecuritySeverity.critical) {
      return SecurityTip(
        title: 'Weak Passwords Detected',
        message: '${weak.count} credential(s) use passwords under $kWeakCriticalBelow characters. Consider updating them with the Generator.',
        category: SecurityTipCategory.weakPasswords,
        actionLabel: 'Open Vault',
      );
    }

    final reuse = byCategory[SecurityTipCategory.reusedPasswords];
    if (reuse != null && reuse.count >= 2) {
      return SecurityTip(
        title: 'Password Reuse Risk',
        message: '${reuse.count} credentials share identical passwords. Reusing passwords increases breach risk.',
        category: SecurityTipCategory.reusedPasswords,
        actionLabel: 'View Reused',
      );
    }

    final no2fa = byCategory[SecurityTipCategory.missing2FA];
    if (no2fa != null &&
        no2fa.count >= 2 &&
        totalLogins >= kTotpPenaltyMinLogins) {
      return SecurityTip(
        title: 'Boost Account Protection',
        message: '${no2fa.count} logins have no 2FA secret stored. Add TOTP secrets to secure your accounts.',
        category: SecurityTipCategory.missing2FA,
        actionLabel: 'Add 2FA',
      );
    }

    final stale = byCategory[SecurityTipCategory.staleCredentials];
    if (stale != null) {
      return SecurityTip(
        title: 'Credential Rotation Reminder',
        message: 'Some credentials have not been updated in over ${(kStaleAfterDays / 30).round()} months. Periodic rotation keeps your vault secure.',
        category: SecurityTipCategory.staleCredentials,
        actionLabel: 'Review Vault',
      );
    }

    if (weak != null) {
      return SecurityTip(
        title: 'Shorten the Gap',
        message: '${weak.count} password(s) are under $kWeakWarnBelow characters. Longer passphrases resist brute force.',
        category: SecurityTipCategory.weakPasswords,
        actionLabel: 'Open Vault',
      );
    }

    return null; // Vault health is optimal
  }
}

/// Occasional-tip surface (72 h cooldown via prefs) kept from the original
/// advisor. The classifier itself now lives in [SecurityAdvisorEngine].
class MiniMLSecurityAdvisor {
  static const String _kLastTipKey = 'last_mini_ml_tip_timestamp';

  /// Evaluates vault health on-device and returns an occasional smart tip if
  /// the cooldown period has passed. Returns null when healthy or suppressed.
  static Future<SecurityTip?> evaluateOccasionalTip(List<DecryptedItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTipMs = prefs.getInt(_kLastTipKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Cooldown: only once every 72 hours.
    const cooldownMs = 72 * 60 * 60 * 1000;
    if (nowMs - lastTipMs < cooldownMs) return null;

    final advisory = SecurityAdvisorEngine.analyze(items);
    final tip = advisory.topTip;
    if (tip != null) {
      await prefs.setInt(_kLastTipKey, nowMs);
    }
    return tip;
  }
}
