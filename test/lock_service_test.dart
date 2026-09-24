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
      await service.copySecret('second', ttl: const Duration(milliseconds: 120));
      await Future.delayed(const Duration(milliseconds: 80));
      // First timer was cancelled; second value still present.
      expect(clipboard, equals('second'));
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
}
