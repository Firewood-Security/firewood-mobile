// Access hardening: the lock screen's one-shot auto-biometric prompt must
// only ever be raised in the foreground. The lock can land while the app is
// not in the foreground — the inactivity timer may fire in the background,
// or an auto-lock-off background exit locks on the way out. A native prompt
// raised from a paused activity would fail silently (leaving no auto-prompt
// on return) or surface over whatever screen the lock interrupted, so it is
// deferred to the next resume — where it can only appear over the lock
// screen itself.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firewood/database/isar_service.dart';
import 'package:firewood/screens/vault_unlock_screen.dart';
import 'package:firewood/services/vault_service.dart';

import 'isar_test_helper.dart';

class _MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _MockPathProviderPlatform(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late List<MethodCall> authCalls;

  // Deliver lifecycle events exactly like the engine does, through the
  // flutter/lifecycle basic channel (the binding's handler is @protected).
  Future<void> sendLifecycleState(
      WidgetTester tester, AppLifecycleState state) async {
    final message = const StringCodec().encodeMessage(state.toString());
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/lifecycle',
      message,
      (_) {},
    );
  }

  setUp(() async {
    await initIsarForTests();
    tempDir = await Directory.systemTemp.createTemp('firewood_gate_');
    PathProviderPlatform.instance = _MockPathProviderPlatform(tempDir.path);
    await IsarService().close(); // fresh handle (singleton) per test
    await VaultService().createVault('GateTestMaster123!');
    // Warm the singleton so the screen's hasAnyVault() resolves from the
    // cached handle (microtasks only — no timers inside the fake zone).
    await IsarService().instance;

    SharedPreferences.setMockInitialValues({'biometric_auth_enabled': true});

    authCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'),
            (MethodCall call) async {
      authCalls.add(call);
      switch (call.method) {
        case 'authenticate':
          return false; // record and cancel — never unlock in this test
        case 'getAvailableBiometrics':
          return <String>['fingerprint'];
        case 'isDeviceSupported':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'), null);
    // The Isar handle is deliberately NOT closed here: teardown runs in the
    // test's fake-async zone, where Isar's close never completes. It is
    // closed at the start of the next setUp (real-async zone), and the
    // process releases it when the test file finishes.
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets(
      'auto-biometric prompt waits for the foreground when the lock '
      'lands backgrounded', (tester) async {
    // The app is on its way out (recents tray / home) when the lock fires.
    await sendLifecycleState(tester, AppLifecycleState.inactive);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: VaultUnlockScreen()),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    Iterable<MethodCall> authentications() =>
        authCalls.where((c) => c.method == 'authenticate');
    expect(authentications(), isEmpty,
        reason: 'a backgrounded lock must not raise the native biometric '
            'prompt — it can only appear once the lock screen is what the '
            'user is actually looking at');

    // Coming back to the foreground: the deferred one-shot prompt fires —
    // over the lock screen, the only thing on screen after the lock.
    await sendLifecycleState(tester, AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(authentications(), hasLength(1),
        reason: 'exactly one deferred prompt on resume, never zero (lost) '
            'and never duplicated');
  });
}
