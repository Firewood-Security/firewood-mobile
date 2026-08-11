// services/analytics_service.dart
// Zero-knowledge, local-only analytics engine for Firewood vault security metrics

import '../models/item_type.dart';
import 'item_service.dart';

class VaultAnalyticsReport {
  final int totalItems;
  final int totalLogins;
  final int strongPasswords;
  final int weakPasswords;
  final int reusedPasswords;
  final int totpEnabledCount;
  final int securityScore; // 0 to 100
  final double totpCoveragePercent;
  final int breachedPasswords;
  final List<String> recommendations;

  VaultAnalyticsReport({
    required this.totalItems,
    required this.totalLogins,
    required this.strongPasswords,
    required this.weakPasswords,
    required this.reusedPasswords,
    required this.totpEnabledCount,
    required this.securityScore,
    required this.totpCoveragePercent,
    this.breachedPasswords = 0,
    required this.recommendations,
  });
}

class VaultAnalyticsService {
  /// Computes privacy-first local security analytics on vault items.
  static VaultAnalyticsReport computeReport(List<DecryptedItem> items) {
    if (items.isEmpty) {
      return VaultAnalyticsReport(
        totalItems: 0,
        totalLogins: 0,
        strongPasswords: 0,
        weakPasswords: 0,
        reusedPasswords: 0,
        totpEnabledCount: 0,
        securityScore: 100,
        totpCoveragePercent: 0.0,
        recommendations: ['Vault is empty. Add your first credential to track security.'],
      );
    }

    final logins = items.where((i) => i.type == ItemType.login.label).toList();
    final passwordMap = <String, int>{};
    int strongCount = 0;
    int weakCount = 0;
    int totpCount = 0;

    for (final login in logins) {
      final pwd = login.fields['password']?.toString() ?? '';
      final totp = login.fields['totp_secret']?.toString() ?? '';

      if (totp.trim().isNotEmpty) {
        totpCount++;
      }

      if (pwd.isNotEmpty) {
        passwordMap[pwd] = (passwordMap[pwd] ?? 0) + 1;

        final isLong = pwd.length >= 12;
        final hasUpper = pwd.contains(RegExp(r'[A-Z]'));
        final hasNumber = pwd.contains(RegExp(r'[0-9]'));
        final hasSpecial = pwd.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

        if (isLong && hasUpper && (hasNumber || hasSpecial)) {
          strongCount++;
        } else if (pwd.length < 8) {
          weakCount++;
        }
      }
    }

    int reusedCount = 0;
    for (final count in passwordMap.values) {
      if (count > 1) {
        reusedCount += (count - 1);
      }
    }

    double totpPercent = logins.isEmpty ? 0.0 : (totpCount / logins.length) * 100;

    // Calculate overall 0-100 Security Score
    double baseScore = 100.0;

    if (logins.isNotEmpty) {
      final weakPenalty = (weakCount / logins.length) * 40.0;
      final reusePenalty = (reusedCount / logins.length) * 35.0;
      final noTotpPenalty = ((logins.length - totpCount) / logins.length) * 25.0;

      baseScore = (100.0 - weakPenalty - reusePenalty - noTotpPenalty).clamp(0.0, 100.0);
    }

    final score = baseScore.round();

    final recs = <String>[];
    if (weakCount > 0) {
      recs.add('$weakCount password(s) are weak (under 8 characters). Update them.');
    }
    if (reusedCount > 0) {
      recs.add('$reusedCount password(s) are reused across multiple sites.');
    }
    if (logins.isNotEmpty && totpCount < logins.length) {
      recs.add('${logins.length - totpCount} account(s) lack 2FA / TOTP protection.');
    }
    if (recs.isEmpty) {
      recs.add('Great job! Vault credentials follow strong security practices.');
    }

    return VaultAnalyticsReport(
      totalItems: items.length,
      totalLogins: logins.length,
      strongPasswords: strongCount,
      weakPasswords: weakCount,
      reusedPasswords: reusedCount,
      totpEnabledCount: totpCount,
      securityScore: score,
      totpCoveragePercent: totpPercent,
      recommendations: recs,
    );
  }
}
