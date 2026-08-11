// app.dart
// Root widget with ProviderScope, MaterialApp and lifecycle handling

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'screens/vault_setup_screen.dart';
import 'screens/vault_unlock_screen.dart';
import 'screens/home_screen.dart';
import 'services/vault_service.dart';
import 'services/lock_service.dart';
import 'services/accent_color_service.dart';
import 'theme/app_theme.dart';

class FirewoodApp extends ConsumerStatefulWidget {
  const FirewoodApp({super.key});

  @override
  ConsumerState<FirewoodApp> createState() => _FirewoodAppState();
}

class _FirewoodAppState extends ConsumerState<FirewoodApp>
    with WidgetsBindingObserver {
  late LockService _lockService;

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App going to background - trigger lock timer
        _lockService.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // App coming to foreground - check if should lock
        _lockService.onAppResumed();
        break;
      default:
        break;
    }
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

    return ValueListenableBuilder<Color>(
      valueListenable: AccentColorService.currentColor,
      builder: (context, accentColor, _) {
        return Listener(
          onPointerDown: (_) => _lockService.onUserInteraction(),
          child: MaterialApp(
            title: 'Firewood',
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

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnlocked = ref.watch(authProvider) != null;

    return FutureBuilder<bool>(
      future: VaultService().hasAnyVault(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
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
                    const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to initialize vault database',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
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