// Auth-policy regression: opening a credential page inside an unlocked
// session is BROWSING — the vault unlock at login is the session's one
// authentication, so the page must open with ZERO local_auth calls (the
// old open-gate re-prompted on every visit). Critical actions on the page
// — masked password reads here — must go through the ReauthService gate.

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firewood/screens/credential_view_screen.dart';
import 'package:firewood/services/item_service.dart';
import 'package:firewood/theme/app_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> authCalls;
  late String? clipboard;

  final item = DecryptedItem(
    itemId: 'item-1',
    type: 'login',
    title: 'Demo Login',
    fields: {
      'username': 'alice@example.com',
      'password': 'hunter2sekrit',
    },
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    authCalls = [];
    clipboard = null;
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
          return false; // the gate falls back to the password dialog
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.firewood.vault_security'),
        (MethodCall call) async {
      if (call.method == 'getLockoutStatus') {
        return {'lockoutRemainingMs': 0, 'isLockedOut': false};
      }
      if (call.method == 'setClipboard') {
        // No native wrapper in tests: fail it so copySecret exercises its
        // documented plain-Clipboard fallback we can observe.
        throw PlatformException(code: 'unsupported');
      }
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform,
        (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String?;
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/local_auth'), null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.firewood.vault_security'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpCredentialView(WidgetTester tester) async {
    // Tall window so every section is laid out without scrolling.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: CredentialViewScreen(
          secretKey: SecretKeyData(List<int>.filled(32, 7)),
          itemService: ItemService(),
          item: item,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // open fade-in
  }

  testWidgets('opening the credential page performs zero authentication',
      (tester) async {
    await pumpCredentialView(tester);

    expect(find.text('DECRYPTED CREDENTIALS'), findsOneWidget);
    expect(find.text('Demo Login'), findsAtLeastNWidgets(1),
        reason: 'the page renders the credential itself (title appears in '
            'the app bar and the header)');
    expect(authCalls, isEmpty,
        reason: 'browsing must never re-prompt — not one local_auth call '
            'on open');
    expect(find.text('Verification Required'), findsNothing,
        reason: 'no gate may appear just from viewing');
  });

  testWidgets('a sensitive copy goes through the verification gate',
      (tester) async {
    await pumpCredentialView(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Copy Password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Verification Required'), findsOneWidget,
        reason: 'masked password reads must re-verify');
    expect(authCalls.where((c) => c.method == 'authenticate'), hasLength(1),
        reason: 'biometric is offered first');

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Verification Required'), findsNothing);
    expect(clipboard, isNull,
        reason: 'a refused gate must copy nothing to the clipboard');
  });

  testWidgets('a non-sensitive copy needs no verification', (tester) async {
    await pumpCredentialView(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Copy User'));
    await tester.pump();

    expect(find.text('Verification Required'), findsNothing,
        reason: 'usernames are not masked reads');
    expect(authCalls, isEmpty);
    expect(clipboard, 'alice@example.com');
  });
}
