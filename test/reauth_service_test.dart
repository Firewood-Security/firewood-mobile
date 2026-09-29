// Critical-action re-authentication gate (auth policy, 2026-09-27).
//
// ReauthService.confirm is the one gate in front of every critical action
// inside an unlocked session (delete, masked password reads, biometric
// enable, override/import, AirShare send, export). These tests pin:
//   - biometric success passes with no password dialog;
//   - the master-password fallback VERIFIES against the vault (the old
//     inline dialogs accepted any non-empty input — fixed);
//   - wrong password keeps the dialog open and records the failure
//     (REQ-AUTH-02);
//   - the gate fails closed when the native rate-limit state cannot be
//     read or is actively locked out — correct input must not slip through.

@Timeout(Duration(minutes: 3))
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:firewood/database/isar_service.dart';
import 'package:firewood/services/reauth_service.dart';
import 'package:firewood/services/vault_service.dart';

import 'isar_test_helper.dart';

class _MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _MockPathProviderPlatform(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

const _masterPassword = 'ReauthFallbackMaster123!';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late List<MethodCall> authCalls;
  late Map<String, dynamic> lockout;
  late bool lockoutReadFails;
  late int failedAttempts;

  Widget host() => const MaterialApp(
        home: Scaffold(body: Text('host')),
      );

  /// Bounded dual-clock poller: master-password verification runs
  /// Argon2id in isolates (real time) and may involve fake-zone timers
  /// (test time). Advance BOTH until [condition] holds.
  Future<void> waitFor(
    WidgetTester tester,
    bool Function() condition,
  ) async {
    for (var i = 0; i < 400 && !condition(); i++) {
      await tester.runAsync(() async =>
          await Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  setUpAll(() async {
    await initIsarForTests();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('firewood_reauth_');
    PathProviderPlatform.instance = _MockPathProviderPlatform(tempDir.path);
    await IsarService().close(); // fresh handle (singleton) per test
    await VaultService().createVault(_masterPassword);
    await IsarService().instance; // warm: no native work inside pumps

    authCalls = [];
    lockout = {'lockoutRemainingMs': 0, 'isLockedOut': false};
    lockoutReadFails = false;
    failedAttempts = 0;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/local_auth'),
        (MethodCall call) async {
      authCalls.add(call);
      switch (call.method) {
        case 'canCheckBiometrics':
        case 'getAvailableBiometrics':
          return <String>['fingerprint'];
        case 'isDeviceSupported':
          return true;
        case 'authenticate':
          return false; // every test drives the fallback explicitly
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.firewood.vault_security'),
        (MethodCall call) async {
      switch (call.method) {
        case 'getLockoutStatus':
          if (lockoutReadFails) {
            throw PlatformException(code: 'unavailable');
          }
          return Map<String, dynamic>.from(lockout);
        case 'recordFailedUnlockAttempt':
          failedAttempts++;
          return Map<String, dynamic>.from(lockout);
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/local_auth'), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.firewood.vault_security'), null);
    // The Isar handle is deliberately NOT closed here (teardown runs in
    // the fake-async zone); the next setUp closes it in a real-async zone.
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets('biometric success passes without any password dialog',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'),
            (MethodCall call) async {
      authCalls.add(call);
      switch (call.method) {
        case 'canCheckBiometrics':
        case 'getAvailableBiometrics':
          return <String>['fingerprint'];
        case 'isDeviceSupported':
          return true;
        case 'authenticate':
          return true;
        default:
          return null;
      }
    });
    await tester.pumpWidget(host());

    final ok = await tester.runAsync(
      () => ReauthService.confirm(
        tester.element(find.text('host')),
        reason: 'Authenticate to delete this credential',
      ),
    );

    expect(ok, isTrue);
    expect(find.text('Verification Required'), findsNothing,
        reason: 'a successful biometric must not fall back to a dialog');
    expect(authCalls.where((c) => c.method == 'authenticate'), hasLength(1));
  });

  testWidgets(
      'password fallback verifies against the vault: wrong rejected, '
      'right accepted', (tester) async {
    await tester.pumpWidget(host());
    final gate = ReauthService.confirm(
      tester.element(find.text('host')),
      reason: 'Authenticate to delete this credential',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Verification Required'), findsOneWidget);
    expect(find.text('Authenticate to delete this credential'), findsOneWidget,
        reason: 'the dialog states why verification is required');
    expect(authCalls.where((c) => c.method == 'authenticate'), hasLength(1),
        reason: 'biometric is offered first');

    // Wrong password: the dialog must stay open with an error — the old
    // inline fallback popped `true` on a non-empty validator alone.
    await tester.enterText(find.byType(TextFormField), 'WrongPassword123!');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
    await tester.pump();
    await waitFor(
        tester,
        () => find
            .textContaining('Invalid master password')
            .evaluate()
            .isNotEmpty);

    expect(find.textContaining('Invalid master password'), findsOneWidget,
        reason: 'the vault must reject the wrong master password');
    expect(find.text('Verification Required'), findsOneWidget,
        reason: 'a failed verification must keep the gate closed');
    expect(failedAttempts, 1, reason: 'REQ-AUTH-02: the failure is recorded');

    // Right password: verification succeeds and the gate opens.
    bool? gateResult;
    gate.then((v) => gateResult = v);
    await tester.enterText(find.byType(TextFormField), _masterPassword);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
    await tester.pump();
    await waitFor(tester, () => gateResult != null);
    await tester.pump();

    expect(gateResult, isTrue,
        reason: 'the master password must be verified against the vault');
    expect(await gate, isTrue);
    expect(failedAttempts, 1, reason: 'a success records no failure');
  });

  testWidgets('unreadable rate-limit state fails closed', (tester) async {
    lockoutReadFails = true;
    await tester.pumpWidget(host());
    final gate = ReauthService.confirm(
      tester.element(find.text('host')),
      reason: 'Authenticate to export the vault',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Even the CORRECT password must not slip through when the native
    // rate-limit state cannot be read — fail closed, no vault attempt.
    await tester.enterText(find.byType(TextFormField), _masterPassword);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Could not verify unlock rate limit'),
        findsOneWidget);
    expect(find.text('Verification Required'), findsOneWidget,
        reason: 'fail closed: no silent success without rate-limit state');
    expect(failedAttempts, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    expect(await gate, isFalse);
  });

  testWidgets('an active lockout refuses before any vault attempt',
      (tester) async {
    lockout = {'lockoutRemainingMs': 42000, 'isLockedOut': true};
    await tester.pumpWidget(host());
    final gate = ReauthService.confirm(
      tester.element(find.text('host')),
      reason: 'Authenticate to share via AirShare',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextFormField), _masterPassword);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Too many failed attempts'), findsOneWidget);
    expect(find.textContaining('Wait 42s'), findsOneWidget);
    expect(failedAttempts, 0,
        reason: 'a locked-out gate must not touch the vault at all');

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    expect(await gate, isFalse);
  });
}
