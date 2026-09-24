import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/accent_color_service.dart';
import 'services/app_version_service.dart';
import 'services/lock_service.dart';
import 'services/native_security_bridge.dart';
import 'services/update_service.dart';
import 'theme/app_icons.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom error handler to log Flutter framework errors and prevent silent white screens in Release mode
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError caught: ${details.exception}');
  };

  // Custom error widget builder to display diagnostic information instead of a blank screen in Release mode
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF121212),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(AppIcons.alertCircle, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'An unexpected error occurred.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  try {
    await AccentColorService.init();
  } catch (e) {
    debugPrint('Failed to initialize AccentColorService: $e');
  }

  // Read the deployed build's version (versionName/versionCode) so every
  // version surface follows the actual installed package.
  await AppVersionService.init();

  try {
    UpdateService.initUpdateChecker();
  } catch (e) {
    debugPrint('Failed to initialize UpdateChecker: $e');
  }

  // Enforce screenshot/recents protection from boot (REQ-SCREEN-01).
  // Fail-safe: any error leaves the OS default, surfaced no further —
  // the Settings toggle remains the user-visible control.
  try {
    await NativeSecurityBridge.applyStoredScreenshotPolicy();
  } catch (e) {
    debugPrint('Failed to apply screenshot policy: $e');
  }

  // Load persisted lock settings before first frame so Gate-0/REQ-SESS-01
  // holds from startup (fail-safe defaults on any error).
  final lockSettings = await LockService.loadPersisted();

  runApp(ProviderScope(
    overrides: [
      lockTimeoutProvider.overrideWith((ref) => lockSettings.timeout),
      autoLockEnabledProvider.overrideWith((ref) => lockSettings.enabled),
    ],
    child: const FirewoodApp(),
  ));
}
