@Timeout(Duration(minutes: 2))
// Phase 3 screen-capture policy tests (REQ-SCREEN-01).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firewood/services/native_security_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.firewood.vault_security');

  final calls = <String>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call.method);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('defaults to protected (enables FLAG_SECURE)', () async {
    SharedPreferences.setMockInitialValues({});
    await NativeSecurityBridge.applyStoredScreenshotPolicy();
    expect(calls, contains('enableSecureFlag'));
    expect(calls, isNot(contains('disableSecureFlag')));
  });

  test('respects explicit opt-out', () async {
    SharedPreferences.setMockInitialValues({'allow_screenshots': true});
    await NativeSecurityBridge.applyStoredScreenshotPolicy();
    expect(calls, contains('disableSecureFlag'));
    expect(calls, isNot(contains('enableSecureFlag')));
  });

  test('explicit opt-in keeps protection', () async {
    SharedPreferences.setMockInitialValues({'allow_screenshots': false});
    await NativeSecurityBridge.applyStoredScreenshotPolicy();
    expect(calls, contains('enableSecureFlag'));
  });
}
