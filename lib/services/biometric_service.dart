// services/biometric_service.dart
// Provides biometric / device passcode verification for sensitive actions

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'lock_service.dart';

class BiometricAuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Authenticate user via Biometrics or Device PIN/Passcode before sensitive transfer
  static Future<bool> authenticateUser({required String reason}) async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        // V-026: fail closed — with no biometric or passcode mechanism there
        // is no authenticated proof, so the sensitive action is refused
        // instead of proceeding unauthenticated.
        return false;
      }

      // Some OEMs surface the device-credential fallback as a system
      // activity (or hold top-resumed state) — that pauses us. Opening the
      // flow keeps the in-progress verification from locking the vault out
      // from under itself; a genuinely long pause still locks via the
      // idle timer.
      LockService.beginForegroundFlow();
      bool didAuthenticate;
      try {
        didAuthenticate = await _localAuth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false, // Allows fallback to Device PIN / Passcode
          ),
        );
      } finally {
        LockService.endForegroundFlow();
      }

      return didAuthenticate;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
