// app.dart
// Root widget with ProviderScope, MaterialApp and lifecycle handling

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'debug/crypto_debug.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/vault_setup_screen.dart';
import 'screens/vault_unlock_screen.dart';
import 'screens/home_screen.dart';
import 'services/autofill_service.dart';
import 'services/vault_service.dart';
import 'services/lock_service.dart';
import 'services/accent_color_service.dart';
import 'theme/app_icons.dart';
import 'theme/app_theme.dart';

class FirewoodApp extends ConsumerStatefulWidget {
  const FirewoodApp({super.key});

  @override
  ConsumerState<FirewoodApp> createState() => _FirewoodAppState();
}

class _FirewoodAppState extends ConsumerState<FirewoodApp>
    with WidgetsBindingObserver {
  late LockService _lockService;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// Native → Flutter bridge for `Activity.onTopResumedActivityChanged`.
  ///
  /// MIUI's recents overview (QuickstepLauncher) hands top-resumed state to
  /// the launcher while our activity stays RESUMED and visible — verified on
  /// the Redmi Note 10 Lite: only `wm_on_top_resumed_lost` + focus loss are
  /// delivered, never `onPause`/`onStop`. Flutter consequently emits only
  /// `inactive`, which must never lock (the biometric prompt produces the
  /// exact same focus loss). System windows like BiometricPrompt are not
  /// activities, so they never change top-resumed state — making this
  /// channel the one safe signal for "the user went to recents / home /
  /// another app" on ROMs that pause lazily.
  static const MethodChannel _lifecycleChannel =
      MethodChannel('net.firewood.app/lifecycle');

  @override
  void initState() {
    super.initState();
    _lockService = ref.read(lockServiceProvider);
    WidgetsBinding.instance.addObserver(this);

    // Configure lock service from settings
    final timeout = ref.read(lockTimeoutProvider);
    final enabled = ref.read(autoLockEnabledProvider);
    _lockService.setLockTimeout(timeout);
    _lockService.setEnabled(enabled);
    _lockService.setLockOnBackground(ref.read(lockOnBackgroundProvider));
    _lockService.setSessionTimeout(ref.read(sessionTimeoutProvider));

    _lifecycleChannel.setMethodCallHandler(_handleNativeLifecycle);

    // Debug-only: gate crypto metrics on wireless debugging detection.
    // Triple gate: kDebugMode + CRYPTO_METRICS dart-define + native check.
    if (kDebugMode &&
        const bool.fromEnvironment('CRYPTO_METRICS', defaultValue: false)) {
      const MethodChannel('com.firewood.vault_security')
          .invokeMethod<bool>('isWirelessDebugging')
          .then((v) => CryptoDebug.setRuntimeEnabled(v ?? false))
          .catchError((_) => CryptoDebug.setRuntimeEnabled(false));
    }
  }

  Future<dynamic> _handleNativeLifecycle(MethodCall call) async {
    if (call.method != 'topResumedActivity') return null;
    if (call.arguments == true) {
      _lockService.onAppResumed();
    } else {
      // Top-resumed lost: apply the exact same rules as a real pause —
      // auto-lock OFF or "Lock in Recent Apps" ON lock at once; otherwise
      // the idle timer keeps running. Idempotent with a later real
      // `hidden`/`paused` event when the ROM does pause (HOME, screen off).
      _lockService.onAppPaused();
    }
    return null;
  }

  @override
  void dispose() {
    _lifecycleChannel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    _lockService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App actually left the foreground (recents, home, screen off, app
        // switch) or the engine is dying — trigger the background lock.
        //
        // `hidden` (Android onPause) is the FIRST durable background
        // signal on Flutter 3.47 and it must lock here, not only at
        // `paused` (onStop): frames still render during `hidden`, so the
        // lock screen is on screen before Android captures the
        // recents-tray snapshot at onStop. Locking only at `paused`
        // rendered the lock too late — the tray card kept showing vault
        // content ("recent tray lock isn't working").
        //
        // `inactive` is deliberately NOT handled here: it only means the
        // window lost focus, which happens for every system overlay —
        // most importantly the biometric prompt itself (system dialogs
        // do not pause the activity, so they never send `hidden`).
        // Routing it to onAppPaused used to lock the vault the moment
        // CredentialView opened its scan (auth -> null under the prompt,
        // stack reset to the login page, and a second auto-scan from
        // VaultUnlockScreen).
        _lockService.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // App coming to foreground - check if should lock
        _lockService.onAppResumed();
        break;
      default:
        // only `inactive` lands here: pure focus loss (system dialogs,
        // biometric prompt, notification shade) — never lock on it. Real
        // background exits arrive as `hidden`/`paused` above, or via the
        // native top-resumed bridge when the ROM skips pause entirely.
        break;
    }
  }

  /// Pops everything above the root route when the vault locks. Deferred to
  /// the end of the current frame so it can never mutate the navigator
  /// mid-build; by registration order it always runs before
  /// VaultUnlockScreen's one-shot post-frame biometric prompt, so that
  /// prompt can only ever appear over the lock screen — never over a
  /// leftover open page.
  void _resetNavigationToLockScreen() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Flicker fix: instant pop (no animation) — the lock screen should
      // appear immediately without a visible route-collapse animation.
      navigator.popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to settings changes
    ref.listen<Duration>(lockTimeoutProvider, (_, timeout) {
      _lockService.setLockTimeout(timeout);
    });
    ref.listen<bool>(autoLockEnabledProvider, (_, enabled) {
      _lockService.setEnabled(enabled);
    });
    ref.listen<bool>(lockOnBackgroundProvider, (_, enabled) {
      _lockService.setLockOnBackground(enabled);
    });
    ref.listen<Duration>(sessionTimeoutProvider, (_, timeout) {
      _lockService.setSessionTimeout(timeout);
    });

    // V-007: the decrypted autofill mirror must never outlive the unlocked
    // session — wipe the Keystore-backed store the moment the vault locks.
    ref.listen(authProvider, (previous, next) {
      if (previous == null && next != null) {
        // Session edge: a fresh unlock opens a fresh absolute session
        // window — logout when the logged time exceeds the cap.
        _lockService.startSession();
      }
      if (previous != null && next == null) {
        _lockService.endSession();
        AutofillService.clear();
        // Access hardening: clearing auth only swaps the root route's
        // content (see _AuthGate). Every route pushed above it — credential,
        // item, search, settings screens and dialogs — still holds
        // decrypted data and would stay usable *on top of* the lock screen
        // (the reported flow: timer locks, biometric prompt is cancelled,
        // and the previously opened password page remains live until Back).
        // Drop the whole stack so every lock path (idle timer, background
        // exit, Lock Now, burner) lands the user on the lock screen itself.
        _resetNavigationToLockScreen();
      }
    });

    return ValueListenableBuilder<Color>(
      valueListenable: AccentColorService.currentColor,
      builder: (context, accentColor, _) {
        return Listener(
          onPointerDown: (_) => _lockService.onUserInteraction(),
          child: MaterialApp(
            title: 'Firewood',
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getDarkTheme(accentColor),
            darkTheme: AppTheme.getDarkTheme(accentColor),
            themeMode: ThemeMode.dark,
            home: const _AuthGate(),
          ),
        );
      },
    );
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  bool _splashCompleted = false;

  // Flicker fix: cache the future so rebuilds don't re-trigger
  // `hasAnyVault()` and flash the loading spinner on every auth change.
  Future<bool>? _hasVaultFuture;

  @override
  Widget build(BuildContext context) {
    if (!_splashCompleted) {
      return SplashScreen(
        onComplete: () {
          if (mounted) setState(() => _splashCompleted = true);
        },
      );
    }

    final isUnlocked = ref.watch(authProvider) != null;

    // Flicker fix: reuse the cached future instead of creating a new one
    // on every rebuild (which causes ConnectionState.waiting → spinner flash).
    _hasVaultFuture ??= VaultService().hasAnyVault();

    return FutureBuilder<bool>(
      future: _hasVaultFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF0C0C0E),
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.orangeAccent,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(AppIcons.alertCircle,
                        color: Colors.orangeAccent, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to initialize vault database',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.data != true) {
          // First launch - show setup screen
          return const VaultSetupScreen();
        }

        if (!isUnlocked) {
          // Vault exists but locked - show unlock screen
          return const VaultUnlockScreen();
        }

        // Vault unlocked - show home
        return const HomeScreen();
      },
    );
  }
}
