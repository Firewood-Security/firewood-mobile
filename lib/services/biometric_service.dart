// services/biometric_service.dart
// Provides biometric / device passcode verification for sensitive actions

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Authenticate user via Biometrics or Device PIN/Passcode before sensitive transfer
  static Future<bool> authenticateUser({required String reason}) async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        // Biometrics or passcode not available on device, proceed
        return true;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allows fallback to Device PIN / Passcode
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
