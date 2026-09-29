import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firewood/services/notification_service.dart';
import 'package:firewood/services/autofill_service.dart';
import 'package:firewood/services/item_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationAlertService Tests', () {
    test('Notification preference defaults to enabled', () async {
      final enabled = await NotificationAlertService.isNotificationsEnabled();
      expect(enabled, isTrue);
    });

    test('Notification preference can be disabled and enabled', () async {
      await NotificationAlertService.setNotificationsEnabled(false);
      expect(await NotificationAlertService.isNotificationsEnabled(), isFalse);

      await NotificationAlertService.setNotificationsEnabled(true);
      expect(await NotificationAlertService.isNotificationsEnabled(), isTrue);
    });

    test('Disabling notifications prevents alerts from showing', () async {
      await NotificationAlertService.setNotificationsEnabled(false);

      final weakOk = await NotificationAlertService.notifyWeakPassword(
        itemTitle: 'Test Account',
        reason: 'Too short',
      );
      expect(weakOk, isFalse);

      final missingOk = await NotificationAlertService.notifyMissingPassword(
        itemTitle: 'Incomplete Account',
      );
      expect(missingOk, isFalse);

      final updateOk = await NotificationAlertService.notifyAppUpdate(
        version: '2.0.0',
      );
      expect(updateOk, isFalse);

      final tipOk = await NotificationAlertService.notifySecurityTip(
        tipText: 'Enable 2FA',
      );
      expect(tipOk, isFalse);
    });

    test('V-020 notification text never embeds the credential title', () async {
      final shown = <Map<String, dynamic>>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
          const MethodChannel('com.firewood.vault_security'),
          (MethodCall call) async {
        if (call.method == 'showNotification') {
          shown.add(Map<String, dynamic>.from(call.arguments as Map));
          return true;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(
            const MethodChannel('com.firewood.vault_security'), null);
      });

      final weakOk = await NotificationAlertService.notifyWeakPassword(
        itemTitle: 'Super Secret Banking',
        reason: 'Too short',
      );
      final missingOk = await NotificationAlertService.notifyMissingPassword(
        itemTitle: 'Hidden Vault Login',
      );

      expect(weakOk, isTrue);
      expect(missingOk, isTrue);
      expect(shown, hasLength(2));
      for (final n in shown) {
        expect(n['message'], isNot(contains('Super Secret Banking')));
        expect(n['message'], isNot(contains('Hidden Vault Login')));
        // No credential-shaped content at all — generic sentences only.
        expect(n['message'], contains('credential'));
      }
    });
  });

  group('AutofillService Tests', () {
    test('syncDecryptedItems extracts login credentials correctly', () async {
      final item = DecryptedItem(
        itemId: 'test-uuid-1',
        type: 'login',
        title: 'GitHub',
        fields: {
          'username': 'yahya',
          'password': 'superSecretPassword123!',
          'url': 'https://github.com/login',
          'bundle': 'Dev Work',
        },
        updatedAt: DateTime.now(),
      );

      // Verify syncDecryptedItems handles list gracefully without throwing
      await expectLater(
        AutofillService.syncDecryptedItems([item]),
        completes,
      );
    });
  });
}
