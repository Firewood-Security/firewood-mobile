// services/mini_ml_advisor.dart
// On-device, zero-knowledge machine learning security tip advisor

import 'package:shared_preferences/shared_preferences.dart';
import '../models/item_type.dart';
import 'item_service.dart';

enum SecurityTipCategory {
  weakPasswords,
  reusedPasswords,
  missing2FA,
  staleCredentials,
  backupDisabled,
  optimalHealth,
}

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

class MiniMLSecurityAdvisor {
  static const String _kLastTipKey = 'last_mini_ml_tip_timestamp';

  /// Evaluates vault metrics using on-device Decision Tree classifier
  /// and returns an occasional smart tip if cooldown period has passed.
  static Future<SecurityTip?> evaluateOccasionalTip(List<DecryptedItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTipMs = prefs.getInt(_kLastTipKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Cooldown: Only trigger once every 72 hours (3 days)
    const cooldownMs = 72 * 60 * 60 * 1000;
    if (nowMs - lastTipMs < cooldownMs) {
      return null; // Suppressed due to cooldown
    }

    final tip = classifyVaultHealth(items);
    if (tip != null && tip.category != SecurityTipCategory.optimalHealth) {
      await prefs.setInt(_kLastTipKey, nowMs);
    }
    return tip;
  }

  /// Decision Tree Classifier running on feature vector X
  static SecurityTip? classifyVaultHealth(List<DecryptedItem> items) {
    if (items.isEmpty) return null;

    final logins = items.where((i) => ItemTypeExt.fromString(i.type) == ItemType.login).toList();
    if (logins.isEmpty) return null;

    int weakCount = 0;
    int totpCount = 0;
    final pwdCounts = <String, int>{};
    DateTime oldestUpdate = DateTime.now();

    for (final item in logins) {
      final pwd = item.fields['password']?.toString() ?? '';
      final totp = item.fields['totp_secret']?.toString() ?? '';

      if (totp.trim().isNotEmpty) totpCount++;
      if (pwd.length < 8) weakCount++;

      if (pwd.isNotEmpty) {
        pwdCounts[pwd] = (pwdCounts[pwd] ?? 0) + 1;
      }

      if (item.updatedAt.isBefore(oldestUpdate)) {
        oldestUpdate = item.updatedAt;
      }
    }

    int reusedCount = 0;
    for (final c in pwdCounts.values) {
      if (c > 1) reusedCount += (c - 1);
    }

    final weakRatio = weakCount / logins.length;
    final reuseRatio = reusedCount / logins.length;
    final totpRatio = totpCount / logins.length;
    final oldestAgeDays = DateTime.now().difference(oldestUpdate).inDays;

    // --- DECISION TREE BRANCHING ---
    if (weakRatio >= 0.25) {
      return SecurityTip(
        title: 'Weak Passwords Detected',
        message: '${(weakRatio * 100).round()}% of your login passwords are under 8 characters. Consider updating them with the Generator.',
        category: SecurityTipCategory.weakPasswords,
        actionLabel: 'Open Vault',
      );
    }

    if (reuseRatio >= 0.20) {
      return SecurityTip(
        title: 'Password Reuse Risk',
        message: '$reusedCount accounts share identical passwords. Reusing passwords increases breach risk.',
        category: SecurityTipCategory.reusedPasswords,
        actionLabel: 'View Reused',
      );
    }

    if (totpRatio < 0.30 && logins.length >= 3) {
      return SecurityTip(
        title: 'Boost Account Protection',
        message: 'Only ${(totpRatio * 100).round()}% of logins have 2FA enabled. Add TOTP secrets to secure your accounts.',
        category: SecurityTipCategory.missing2FA,
        actionLabel: 'Add 2FA',
      );
    }

    if (oldestAgeDays > 120) {
      return SecurityTip(
        title: 'Credential Rotation Reminder',
        message: 'Some credentials have not been updated in over 4 months. Periodically rotating passwords keeps your vault secure.',
        category: SecurityTipCategory.staleCredentials,
        actionLabel: 'Review Vault',
      );
    }

    return null; // Vault health is optimal
  }
}
