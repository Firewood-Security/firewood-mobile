// Engine tests for the unified security advisor (fold-in of the former
// decision-tree classifier, analytics counters, and issue collector).
// Pure in-memory: no Isar, no prefs, no network.

import 'package:flutter_test/flutter_test.dart';
import 'package:firewood/models/item_type.dart';
import 'package:firewood/services/item_service.dart';
import 'package:firewood/services/mini_ml_advisor.dart';

final _now = DateTime(2026, 9, 24);

DecryptedItem _login(
  String title, {
  String password = '',
  String totp = '',
  int ageDays = 0,
}) {
  final stamp = _now.subtract(Duration(days: ageDays));
  return DecryptedItem(
    itemId: 'id-$title',
    type: ItemType.login.name,
    title: title,
    fields: <String, dynamic>{
      if (password.isNotEmpty) 'password': password,
      if (totp.isNotEmpty) 'totp_secret': totp,
    },
    updatedAt: stamp,
    createdAt: stamp,
  );
}

SecurityFindingGroup? _group(VaultAdvisory a, SecurityTipCategory c) {
  for (final g in a.groups) {
    if (g.category == c) return g;
  }
  return null;
}

void main() {
  group('SecurityAdvisorEngine', () {
    test('empty vault is all clear with a perfect score', () {
      final a = SecurityAdvisorEngine.analyze([], now: _now);
      expect(a.allClear, isTrue);
      expect(a.issueCount, 0);
      expect(a.securityScore, 100);
      expect(a.groups, isEmpty);
      expect(a.topTip, isNull);
    });

    test('strong unique password with 2FA produces no findings', () {
      final a = SecurityAdvisorEngine.analyze([
        _login('GitHub', password: 'Str0ng!Pass#2026', totp: 'JBSWY3DP'),
      ], now: _now);
      expect(a.allClear, isTrue);
      expect(a.strongCount, 1);
      expect(a.totpCoveragePercent, 100);
      expect(a.securityScore, 100);
    });

    test('missing 2FA is reported but not scored below 3 logins (decision 4.2)',
        () {
      final a = SecurityAdvisorEngine.analyze([
        _login('Solo', password: 'Str0ng!Pass#2026'),
      ], now: _now);
      final g = _group(a, SecurityTipCategory.missing2FA);
      expect(g, isNotNull);
      expect(g!.severity, SecuritySeverity.info);
      expect(a.issueCount, 1);
      // No penalty for a single-login vault.
      expect(a.securityScore, 100);
      expect(a.topTip, isNull);
    });

    test('missing 2FA penalizes the score at 3+ logins and yields a tip', () {
      final a = SecurityAdvisorEngine.analyze([
        _login('A', password: 'Str0ng!Pass#2026', totp: 'JBSWY3DP'),
        _login('B', password: 'An0ther!Pass#2026'),
        _login('C', password: 'Y3tAnother!Pwd'),
      ], now: _now);
      expect(_group(a, SecurityTipCategory.missing2FA)!.count, 2);
      expect(a.securityScore, lessThan(100));
      expect(a.topTip?.category, SecurityTipCategory.missing2FA);
    });

    test('critical weakness (< 8) ranks above everything else', () {
      final a = SecurityAdvisorEngine.analyze([
        _login('Weak', password: 'abc123'),
        _login('Reused1', password: 'Dup3!Password#X'),
        _login('Reused2', password: 'Dup3!Password#X'),
        _login('Stale', password: 'Str0ng!Pass#2026', ageDays: 200),
      ], now: _now);
      expect(a.groups.first.category, SecurityTipCategory.weakPasswords);
      expect(a.groups.first.severity, SecuritySeverity.critical);
      expect(a.topTip?.category, SecurityTipCategory.weakPasswords);
    });

    test('reuse detection is normalized (trim + case-insensitive)', () {
      final a = SecurityAdvisorEngine.analyze([
        _login('Bank', password: '  Secret!Val#2026 '),
        _login('Email', password: 'secret!val#2026'),
      ], now: _now);
      final g = _group(a, SecurityTipCategory.reusedPasswords);
      expect(g, isNotNull);
      expect(g!.count, 2);
      expect(a.reusedCount, 1);
    });

    test('3+ shared passwords escalate reuse to critical', () {
      final a = SecurityAdvisorEngine.analyze([
        _login('A', password: 'Same!Password#2026'),
        _login('B', password: 'Same!Password#2026'),
        _login('C', password: 'Same!Password#2026'),
      ], now: _now);
      expect(_group(a, SecurityTipCategory.reusedPasswords)!.severity,
          SecuritySeverity.critical);
    });

    test('password matching the account name is predictable', () {
      final a = SecurityAdvisorEngine.analyze([
        _login('githubcorporate', password: 'githubcorporate'),
      ], now: _now);
      final g = _group(a, SecurityTipCategory.weakPasswords);
      expect(g, isNotNull);
      expect(g!.issues.first.detail, contains('account name'));
      expect(g.severity, SecuritySeverity.warn);
    });

    test('stale credentials are flagged after 120 days', () {
      final fresh = SecurityAdvisorEngine.analyze([
        _login('Fresh', password: 'Str0ng!Pass#2026', ageDays: 10),
      ], now: _now);
      expect(_group(fresh, SecurityTipCategory.staleCredentials), isNull);

      final stale = SecurityAdvisorEngine.analyze([
        _login('Old', password: 'Str0ng!Pass#2026', ageDays: 200),
      ], now: _now);
      final g = _group(stale, SecurityTipCategory.staleCredentials);
      expect(g, isNotNull);
      expect(g!.issues.first.detail, contains('200 days'));
    });

    test('stale findings apply to non-login-only vaults', () {
      final oldCard = DecryptedItem(
        itemId: 'card-1',
        type: ItemType.card.name,
        title: 'Old Card',
        fields: const <String, dynamic>{'number': '4111111111111111'},
        updatedAt: _now.subtract(const Duration(days: 300)),
        createdAt: _now.subtract(const Duration(days: 300)),
      );
      final a = SecurityAdvisorEngine.analyze([oldCard], now: _now);
      final g = _group(a, SecurityTipCategory.staleCredentials);
      expect(g, isNotNull);
      expect(g!.count, 1);
      expect(a.totalLogins, 0);
      expect(a.securityScore, 100);
    });

    test('score stays clamped within 0..100 on extreme input', () {
      final a = SecurityAdvisorEngine.analyze([
        _login('A', password: 'x'),
        _login('B', password: 'x'),
        _login('C', password: 'x'),
      ], now: _now);
      expect(a.securityScore, inInclusiveRange(0, 100));
      expect(a.securityScore, lessThan(60)); // heavily penalized
    });

    test('groups are ordered worst-severity first', () {
      final a = SecurityAdvisorEngine.analyze([
        _login('Weak', password: 'abc'),
        _login('Ok', password: 'Str0ng!Pass#2026'),
        _login('Stale', password: 'An0ther!Pass#2026', ageDays: 365),
      ], now: _now);
      final ranks =
          a.groups.map((g) => severityRank(g.severity)).toList();
      final sorted = [...ranks]..sort();
      expect(ranks, sorted);
    });
  });
}
