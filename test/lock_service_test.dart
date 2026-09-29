@Timeout(Duration(minutes: 2))
// Phase 3 lock/clipboard tests (REQ-CLIP-01, REQ-SESS-01).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firewood/services/lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LockService.copySecret', () {
    String? clipboard;
    setUp(() {
      clipboard = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return {'text': clipboard ?? ''};
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('sets clipboard then clears after TTL', () async {
      final service = LockService();
      await service.copySecret('s3cr3t', ttl: const Duration(milliseconds: 50));
      expect(clipboard, equals('s3cr3t'));
      await Future.delayed(const Duration(milliseconds: 200));
      expect(clipboard, equals(''));
      service.dispose();
    });

    test('re-copy resets the pending clear timer', () async {
      final service = LockService();
      await service.copySecret('first', ttl: const Duration(milliseconds: 80));
      await Future.delayed(const Duration(milliseconds: 40));
      await service.copySecret('second',
          ttl: const Duration(milliseconds: 120));
      await Future.delayed(const Duration(milliseconds: 80));
      // First timer was cancelled; second value still present.
      expect(clipboard, equals('second'));
      service.dispose();
    });

    test('V-017 places secrets via the native sensitive-clip channel',
        () async {
      final nativeCalls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
          const MethodChannel('com.firewood.vault_security'),
          (MethodCall call) async {
        nativeCalls.add(call);
        return true;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(
            const MethodChannel('com.firewood.vault_security'), null);
      });

      final service = LockService();
      await service.copySecret('s3cr3t', ttl: const Duration(seconds: 30));

      final nativeSet =
          nativeCalls.where((c) => c.method == 'setClipboard').toList();
      expect(nativeSet, hasLength(1),
          reason: 'copySecret must go through the native wrapper so the clip '
              'carries EXTRA_IS_SENSITIVE');
      expect((nativeSet.single.arguments as Map)['text'], 's3cr3t');
      // Native path taken → the plain Flutter setData path was not used.
      expect(clipboard, isNull);
      service.dispose();
    });
  });

  group('LockService persistence (REQ-SESS-01)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults when nothing persisted', () async {
      final loaded = await LockService.loadPersisted();
      expect(loaded.timeout, equals(const Duration(minutes: 5)));
      expect(loaded.enabled, isTrue);
    });

    test('roundtrips timeout and enabled flag', () async {
      await LockService.persistTimeout(const Duration(minutes: 1));
      await LockService.persistEnabled(false);
      final loaded = await LockService.loadPersisted();
      expect(loaded.timeout, equals(const Duration(minutes: 1)));
      expect(loaded.enabled, isFalse);
    });

    test('rejects foreign timeout values on load', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lock_timeout_seconds', 999999);
      final loaded = await LockService.loadPersisted();
      expect(loaded.timeout, equals(const Duration(minutes: 5)));
    });
  });

  group('LockService background locking (access hardening)', () {
    test('backgrounding locks immediately when auto-lock is disabled',
        () async {
      final service = LockService();
      var locks = 0;
      service.setAutoLockCallback(() => locks++);
      service.setEnabled(false);

      // Leaving the app (recents tray, home, screen off) must lock the
      // vault right away even with the inactivity timer turned off — the
      // setting only suspends the idle timer, never the background lock.
      service.onAppPaused();
      expect(locks, 1,
          reason: 'auto-lock-off must still lock on background exit');

      // A real exit reports each of its events (paused + detached); the
      // provider-level callback de-dupes the actual unlocked -> locked
      // transition. Transient `inactive` focus loss is not routed here
      // at all (see app.dart) — that was the credential-view bug.
      service.onAppPaused();
      service.onAppPaused();
      expect(locks, 3);
      service.dispose();
    });

    test(
        'focus return without a preceding pause never locks (stale pause '
        'guard)', () async {
      final service = LockService();
      var locks = 0;
      service.setAutoLockCallback(() => locks++);
      service.setLockTimeout(const Duration(milliseconds: 100));
      // Idle-timer semantics under test: recents-tray lock opted out.
      service.setLockOnBackground(false);

      service.onAppPaused(); // real background exit, timer armed
      await Future.delayed(const Duration(milliseconds: 40));
      service.onAppResumed(); // quick return: before the timeout, no lock
      expect(locks, 0);

      await Future.delayed(const Duration(milliseconds: 150));
      // A system overlay (biometric prompt) dismissing causes a resume
      // with NO pause in between. The old `_lastActivity` was never
      // cleared on resume, so this compared against the stale first
      // pause and locked the vault on every prompt dismissal.
      service.onAppResumed();
      expect(locks, 0,
          reason: 'resume without a pause must not consult the clock');
      service.dispose();
    });

    test(
        'with the recents option OFF, backgrounding arms the timeout '
        'instead of locking at once', () async {
      final service = LockService();
      var locks = 0;
      service.setAutoLockCallback(() => locks++);
      service.setLockTimeout(const Duration(milliseconds: 200));
      // The recents-tray lock defaults ON; this is the explicit opt-out
      // path back to the pre-option behavior.
      service.setLockOnBackground(false);

      service.onAppPaused();
      expect(locks, 0, reason: 'enabled mode honors the configured timeout');
      await Future.delayed(const Duration(milliseconds: 80));
      expect(locks, 0, reason: 'must not lock before the timeout elapses');
      await Future.delayed(const Duration(milliseconds: 250));
      expect(locks, 1, reason: 'timeout expiry must fire the lock');
      service.dispose();
    });

    test('foreground interaction before the timeout restarts the clock',
        () async {
      final service = LockService();
      var locks = 0;
      service.setAutoLockCallback(() => locks++);
      service.setLockTimeout(const Duration(milliseconds: 400));
      // Idle-timer semantics under test: recents-tray lock opted out.
      service.setLockOnBackground(false);

      service.onAppPaused();
      await Future.delayed(const Duration(milliseconds: 100));
      service.onUserInteraction(); // back in the app, user keeps working
      await Future.delayed(const Duration(milliseconds: 200));
      expect(locks, 0, reason: 'interaction restarted the clock');
      await Future.delayed(const Duration(milliseconds: 250));
      expect(locks, 1, reason: 'the restarted clock still locks');
      service.dispose();
    });
  });

  group('LockService "Lock in Recent Apps" option', () {
    test('ON locks at once on background exit even with auto-lock enabled',
        () async {
      final service = LockService();
      var locks = 0;
      service.setAutoLockCallback(() => locks++);
      service.setEnabled(true);
      service.setLockTimeout(const Duration(minutes: 5));
      service.setLockOnBackground(true);

      service.onAppPaused();
      expect(locks, 1,
          reason: 'the option must lock immediately, not arm the idle '
              'timer — the recents tray would keep showing vault content '
              'until the timeout');
      expect(service.lockOnBackground, isTrue);
      service.dispose();
    });

    test('default is ON (secure out of the box)', () async {
      final service = LockService();
      expect(service.lockOnBackground, isTrue,
          reason: 'the recents tray must lock without any setup');
      service.dispose();
    });

    test(
        'explicit opt-out (OFF) keeps the pre-existing behavior: idle '
        'timer armed', () async {
      final service = LockService();
      var locks = 0;
      service.setAutoLockCallback(() => locks++);
      service.setEnabled(true);
      service.setLockTimeout(const Duration(milliseconds: 200));
      service.setLockOnBackground(false);

      expect(service.lockOnBackground, isFalse);
      service.onAppPaused();
      expect(locks, 0,
          reason: 'without the option, backgrounding arms the timeout');
      await Future.delayed(const Duration(milliseconds: 300));
      expect(locks, 1, reason: 'the armed timeout still locks');
      service.dispose();
    });

    test(
        'user setting priority: recents OFF + auto-lock OFF does NOT lock on background',
        () async {
      final service = LockService();
      var locks = 0;
      service.setAutoLockCallback(() => locks++);
      service.setEnabled(false);
      service.setLockOnBackground(false);

      service.onAppPaused();
      expect(locks, 0,
          reason: 'the user turned OFF "Lock in Recent Apps" — the toggle '
              'is the single authority for background locking and must be '
              'respected regardless of the auto-lock setting');
      service.dispose();
    });

    test(
        'user setting priority: recents ON + auto-lock OFF still locks on background',
        () async {
      final service = LockService();
      var locks = 0;
      service.setAutoLockCallback(() => locks++);
      service.setEnabled(false);
      service.setLockOnBackground(true);

      service.onAppPaused();
      expect(locks, 1,
          reason: 'recents ON means background exit locks, even with '
              'auto-lock OFF');
      service.dispose();
    });
  });

  group('LockService session cap (logout when logged time exceeded)', () {
    test('session expiry fires the lock and spends the window', () async {
      final service = LockService();
      var locks = 0;
      service.setAutoLockCallback(() => locks++);
      service.setSessionTimeout(const Duration(milliseconds: 120));
      expect(service.hasActiveSession, isFalse);

      service.startSession();
      expect(service.hasActiveSession, isTrue);
      await Future.delayed(const Duration(milliseconds: 260));
      expect(locks, 1,
          reason: 'exceeding the logged-in time must log out even with no '
              'idle activity');
      expect(service.hasActiveSession, isFalse,
          reason: 'a fired window is spent, not active');
      service.dispose();
    });

    test('endSession cancels the window', () async {
      final service = LockService();
      var locks = 0;
      service.setAutoLockCallback(() => locks++);
      service.setSessionTimeout(const Duration(milliseconds: 120));

      service.startSession();
      service.endSession();
      expect(service.hasActiveSession, isFalse);
      await Future.delayed(const Duration(milliseconds: 260));
      expect(locks, 0, reason: 'a logged-out session must not fire later');
      service.dispose();
    });

    test('a fresh unlock restarts the window', () async {
      final service = LockService();
      var locks = 0;
      service.setAutoLockCallback(() => locks++);
      service.setSessionTimeout(const Duration(milliseconds: 160));

      service.startSession(); // first unlock
      await Future.delayed(const Duration(milliseconds: 120));
      service.startSession(); // re-unlock: a fresh full window
      await Future.delayed(const Duration(milliseconds: 100));
      expect(locks, 0,
          reason: 'the restarted window must not fire on the first '
              "window's clock");
      await Future.delayed(const Duration(milliseconds: 120));
      expect(locks, 1, reason: 'the fresh window still expires');
      service.dispose();
    });

    test('setSessionTimeout applies to the running window', () async {
      final service = LockService();
      var locks = 0;
      service.setAutoLockCallback(() => locks++);
      service.setSessionTimeout(const Duration(seconds: 30));

      service.startSession();
      service.setSessionTimeout(const Duration(milliseconds: 120));
      await Future.delayed(const Duration(milliseconds: 260));
      expect(locks, 1,
          reason: 'a new cap must apply to the session already running');
      service.dispose();
    });
  });

  group('LockService session/option persistence (REQ-SESS-01)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults: 1h session, recents lock ON', () async {
      final loaded = await LockService.loadPersisted();
      expect(loaded.session, equals(const Duration(hours: 1)));
      expect(loaded.lockOnBackground, isTrue);
    });

    test('roundtrips session timeout and recents option', () async {
      await LockService.persistSessionTimeout(const Duration(hours: 2));
      // Roundtrip the NON-default so a silent default can't fake a pass.
      await LockService.persistLockOnBackground(false);
      final loaded = await LockService.loadPersisted();
      expect(loaded.session, equals(const Duration(hours: 2)));
      expect(loaded.lockOnBackground, isFalse);
    });

    test('rejects foreign session values on load', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('session_timeout_minutes', 999999);
      final loaded = await LockService.loadPersisted();
      expect(loaded.session, equals(const Duration(hours: 1)));
    });
  });
}
