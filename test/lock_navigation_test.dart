// Lock access hardening: locking the vault (authProvider → null) must drop
// every route pushed above the root so the lock screen is what the user
// actually sees. Otherwise the previously opened page (credential/item
// screens holding decrypted data) stays usable *on top of* the lock screen
// — the reported flow was: timer locks, the auto-biometric prompt is
// cancelled, and the opened password page remains live until Back.

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firewood/app.dart';
import 'package:firewood/providers/auth_provider.dart';
import 'package:firewood/services/lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auth -> null pops every pushed route back to the lock screen',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FirewoodApp()));
    await tester.pump();

    const sensitiveKey = ValueKey<String>('open-sensitive-page');
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final pushedRoute = MaterialPageRoute<void>(
      builder: (_) =>
          const Scaffold(body: Text('open sensitive page', key: sensitiveKey)),
    );
    navigator.push<void>(pushedRoute);
    // The pushed route content lands on the second frame after push.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(sensitiveKey), findsOneWidget,
        reason: 'precondition: a detail page is pushed above the root');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FirewoodApp)),
    );

    // Simulate an unlocked session, then the lock transition (any lock
    // path — idle timer, background exit, Lock Now, burner — funnels
    // through this same authProvider edge).
    container.read(authProvider.notifier).state = SecretKeyData([9, 9, 9]);
    await tester.pump();
    container.read(authProvider.notifier).state = null;
    await tester.pump(); // frame; the post-frame reset pops the route
    // Drive the exit transition to completion. Each pump must carry elapsed
    // time (the ticker takes its baseline tick on the first frame after the
    // pop), so step in small increments until the route fully unmounts.
    for (var i = 0;
        i < 20 && find.byKey(sensitiveKey).evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(); // frame after the exit animation completes

    expect(pushedRoute.isActive, isFalse,
        reason: 'the lock must remove the opened route from the navigator '
            'history itself, not just hide it');
    expect(find.byKey(sensitiveKey), findsNothing,
        reason: 'a lock must remove every opened page above the lock '
            'screen — leftover routes keep decrypted data usable after '
            'the session ended');
    expect(find.byType(FirewoodApp), findsOneWidget);
  });

  testWidgets(
      'transient focus loss (inactive) must not lock — only a real '
      'background exit does', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FirewoodApp()));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FirewoodApp)),
    );
    // The reported bug lived in auto-lock OFF mode: any `inactive` event
    // went straight to the immediate background lock.
    container.read(autoLockEnabledProvider.notifier).state = false;
    container.read(authProvider.notifier).state = SecretKeyData([9, 9, 9]);
    await tester.pump();

    // Push a route on top (stands in for CredentialViewScreen, whose
    // biometric prompt is what causes the window to lose focus).
    const sensitiveKey = ValueKey<String>('credential-view-page');
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final pushedRoute = MaterialPageRoute<void>(
      builder: (_) =>
          const Scaffold(body: Text('credential view', key: sensitiveKey)),
    );
    navigator.push<void>(pushedRoute);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(sensitiveKey), findsOneWidget);

    // The biometric prompt makes Flutter emit `inactive` (focus loss).
    await sendLifecycle(tester, 'AppLifecycleState.inactive');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(container.read(authProvider), isNotNull,
        reason: 'focus loss is not leaving the app — the session must '
            'survive it (this was the immediate jump to the login page)');
    expect(find.byKey(sensitiveKey), findsOneWidget,
        reason: 'the open credential page must stay usable under a '
            'system overlay such as the biometric prompt');

    // A REAL background exit must still lock with auto-lock disabled.
    await sendLifecycle(tester, 'AppLifecycleState.paused');
    await tester.pump();
    expect(container.read(authProvider), isNull,
        reason: 'recents/home/screen-off still locks with the timer off');
    expect(pushedRoute.isActive, isFalse,
        reason: 'the lock edge must pop the credential route from history');

    // Real flow: the user then RETURNS to the app. Tick-based animations
    // are frozen while the binding is paused (exactly like on a real
    // device), so the exit transition only runs after the resume — and
    // what the user must see on return is the lock screen, not the
    // credential page.
    await sendLifecycle(tester, 'AppLifecycleState.resumed');
    await tester.pump();
    for (var i = 0;
        i < 20 && find.byKey(sensitiveKey).evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(sensitiveKey), findsNothing,
        reason: 'returning to the app must land on the lock screen with '
            'the credential route removed');
  });

  testWidgets('unlock opens the session window, lock ends it', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FirewoodApp()));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FirewoodApp)),
    );
    final lockService = container.read(lockServiceProvider);
    expect(lockService.hasActiveSession, isFalse);

    // Unlock edge (auth null -> key): the absolute session window opens.
    container.read(authProvider.notifier).state = SecretKeyData([7, 7, 7]);
    await tester.pump();
    expect(lockService.hasActiveSession, isTrue,
        reason: 'a fresh unlock must start the logged-time session window');

    // Lock edge (key -> null): the window ends with the session so a
    // stale timer can never fire after logout.
    container.read(authProvider.notifier).state = null;
    await tester.pump();
    expect(lockService.hasActiveSession, isFalse,
        reason: 'logging out must cancel the session timer');
  });

  testWidgets(
      'recents tray: `hidden` (onPause) locks while frames still render, '
      '`inactive` never does', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FirewoodApp()));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FirewoodApp)),
    );
    final lockService = container.read(lockServiceProvider);
    expect(lockService.lockOnBackground, isTrue,
        reason: 'the recents-tray lock defaults to ON (secure by default)');

    container.read(authProvider.notifier).state = SecretKeyData([7, 7, 7]);
    await tester.pump();

    // Focus loss alone (system overlay, biometric prompt): never locks.
    await sendLifecycle(tester, 'AppLifecycleState.inactive');
    await tester.pump();
    expect(container.read(authProvider), isNotNull,
        reason: 'focus loss alone must not lock');

    // Android onPause: the lock must be live NOW — Android captures the
    // recents-tray snapshot from this surface, before onStop/`paused`
    // ever arrives. Locking only at `paused` left the tray card showing
    // vault content.
    await sendLifecycle(tester, 'AppLifecycleState.hidden');
    await tester.pump();
    expect(container.read(authProvider), isNull,
        reason: 'hidden (onPause) must lock so the tray card can only '
            'capture the lock screen');

    // Return from the tray: still locked.
    await sendLifecycle(tester, 'AppLifecycleState.resumed');
    await tester.pump();
    expect(container.read(authProvider), isNull,
        reason: 'coming back from recents lands on the lock screen');
  });

  testWidgets(
      'recents tray with the option OFF: hidden arms the idle timer '
      'instead of locking', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        lockOnBackgroundProvider.overrideWith((ref) => false),
      ],
      child: const FirewoodApp(),
    ));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FirewoodApp)),
    );
    container.read(authProvider.notifier).state = SecretKeyData([7, 7, 7]);
    await tester.pump();

    await sendLifecycle(tester, 'AppLifecycleState.hidden');
    await tester.pump();
    expect(container.read(authProvider), isNotNull,
        reason: 'the opt-out keeps the pre-existing behavior: the idle '
            'timer runs in the background instead of locking at once');

    // End the session edge so no timers outlive the test.
    container.read(authProvider.notifier).state = null;
    await tester.pump();
  });

  testWidgets(
      'native top-resumed loss locks (MIUI recents never pause the app); '
      'a bare grant never does', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FirewoodApp()));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FirewoodApp)),
    );
    container.read(authProvider.notifier).state = SecretKeyData([7, 7, 7]);
    await tester.pump();

    // A bare top-resumed grant (app start, a system window closing) must
    // never consult the clock — mirrors the focus-return stale-pause guard.
    await sendTopResumed(tester, true);
    expect(container.read(authProvider), isNotNull,
        reason: 'a grant without a preceding loss must not lock');

    // Recents tray on this ROM: launcher takes top-resumed, our activity
    // stays RESUMED — no `hidden`/`paused` ever arrive from Flutter.
    await sendTopResumed(tester, false);
    expect(container.read(authProvider), isNull,
        reason: 'top-resumed loss must lock even when onPause never fires');

    // Coming back only clears the pause bookkeeping — auth stays null until
    // the user actually unlocks (resume never restores the session).
    await sendTopResumed(tester, true);
    expect(container.read(authProvider), isNull,
        reason: 'returning from recents lands on the lock screen');
  });

  testWidgets('top-resumed loss with auto-lock kept OFF locks unconditionally',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        autoLockEnabledProvider.overrideWith((ref) => false),
      ],
      child: const FirewoodApp(),
    ));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FirewoodApp)),
    );
    container.read(authProvider.notifier).state = SecretKeyData([7, 7, 7]);
    await tester.pump();

    await sendTopResumed(tester, false);
    expect(container.read(authProvider), isNull,
        reason: 'auto-lock OFF never suspends the background lock — leaving '
            'the screen (recents/home/switch) must still lock, option or not');

    container.read(authProvider.notifier).state = null;
    await tester.pump();
  });

  testWidgets(
      'foreground-flow exemption: hidden during a file pick arms the timer, '
      'not the lock — and the exemption is released afterwards',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FirewoodApp()));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FirewoodApp)),
    );
    container.read(authProvider.notifier).state = SecretKeyData([7, 7, 7]);
    await tester.pump();

    // Import/export/attach flows open system pickers that pause the app —
    // without the exemption the vault would lock mid-action and dump the
    // user back to the unlock screen after choosing a file.
    LockService.beginForegroundFlow();
    await sendLifecycle(tester, 'AppLifecycleState.hidden');
    expect(container.read(authProvider), isNotNull,
        reason: 'a pause inside an app-initiated system flow must not lock');

    // Returning from the picker continues the flow, unlocked.
    await sendLifecycle(tester, 'AppLifecycleState.resumed');
    expect(container.read(authProvider), isNotNull,
        reason: 'coming back from the picker resumes the flow');

    LockService.endForegroundFlow();

    // Exemption over: a plain background exit locks again.
    await sendLifecycle(tester, 'AppLifecycleState.hidden');
    expect(container.read(authProvider), isNull,
        reason: 'after the flow ends the recents/background lock is back');

    await sendLifecycle(tester, 'AppLifecycleState.resumed');
    container.read(authProvider.notifier).state = null;
    await tester.pump();
  });

  testWidgets(
      'flow exemption is bounded: a background pause longer than the timeout '
      'locks via the idle timer', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FirewoodApp()));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FirewoodApp)),
    );
    container.read(authProvider.notifier).state = SecretKeyData([7, 7, 7]);
    await tester.pump();

    LockService.beginForegroundFlow();
    await sendLifecycle(tester, 'AppLifecycleState.hidden');
    expect(container.read(authProvider), isNotNull,
        reason: 'immediately after the pause the exemption holds');

    await tester.pump(const Duration(minutes: 6));
    expect(container.read(authProvider), isNull,
        reason: 'the flow arms the idle timer — wandering off for longer '
            'than the timeout still locks the vault');

    LockService.endForegroundFlow();
    await sendLifecycle(tester, 'AppLifecycleState.resumed');
    container.read(authProvider.notifier).state = null;
    await tester.pump();
  });

  testWidgets(
      'auto-lock OFF + flow: resume cancels the flow timer so it cannot '
      'fire while the user actively works', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        autoLockEnabledProvider.overrideWith((ref) => false),
      ],
      child: const FirewoodApp(),
    ));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FirewoodApp)),
    );
    container.read(authProvider.notifier).state = SecretKeyData([7, 7, 7]);
    await tester.pump();

    LockService.beginForegroundFlow();
    await sendLifecycle(tester, 'AppLifecycleState.hidden');
    expect(container.read(authProvider), isNotNull,
        reason: 'the flow suspends even the unconditional background lock');

    await sendLifecycle(tester, 'AppLifecycleState.resumed');
    await tester.pump(const Duration(minutes: 6));
    expect(container.read(authProvider), isNotNull,
        reason: 'the timer armed during the flow must be cancelled on '
            'resume — it may not lock an actively used vault');

    LockService.endForegroundFlow();

    // Contract restored the moment the flow ends.
    await sendLifecycle(tester, 'AppLifecycleState.hidden');
    expect(container.read(authProvider), isNull,
        reason: 'auto-lock OFF still locks unconditionally on background '
            'exit outside a flow');
    await sendLifecycle(tester, 'AppLifecycleState.resumed');
  });
}

/// Simulates the native `MainActivity.onTopResumedActivityChanged` bridge.
Future<void> sendTopResumed(WidgetTester tester, bool top) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'net.firewood.app/lifecycle',
    const StandardMethodCodec()
        .encodeMethodCall(MethodCall('topResumedActivity', top)),
    (_) {},
  );
  await tester.pump();
}

/// Deliver a lifecycle event exactly like the engine does, through the
/// flutter/lifecycle basic channel (the binding's handler is @protected).
Future<void> sendLifecycle(WidgetTester tester, String state) async {
  final message = const StringCodec().encodeMessage(state);
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    message,
    (_) {},
  );
}
