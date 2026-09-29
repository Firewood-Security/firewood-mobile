// services/native_security_bridge.dart
// Flutter ↔ Android Native security bridge via MethodChannel.
//
// This replaces the raw FlutterSecureStorage password storage pattern
// (CRITICAL P1 in SECURITY_AUDIT.md) with Android Keystore key-wrapping.
//
// All biometric unlock operations now flow through Android Keystore where:
//  1. An AES-256-GCM wrapping key is created in the Android Keystore
//     (hardware backing is device-dependent and UNVERIFIED per-device;
//     see ADR-003 — never surface "hardware-backed" in user-facing copy)
//  2. The master password is encrypted with this key
//  3. Only the encrypted blob is stored on disk (EncryptedSharedPreferences)
//  4. Biometric auth is enforced by Keystore BEFORE decryption is allowed
//  5. Raw master password never touches SharedPreferences or FlutterSecureStorage
//
// This file is the Dart-side thin wrapper; all crypto happens in Kotlin.

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NativeSecurityBridge {
  static const _channel = MethodChannel('com.firewood.vault_security');

  // --- Biometric Key Wrapping (Keystore-backed) ---

  /// Creates an AES-256-GCM wrapping key in Android Keystore bound to biometrics.
  /// Must be called before any [wrapMasterPassword] or [unwrapMasterPassword].
  ///
  /// V-016: the user-auth binding (`userAuthenticationRequired=true`,
  /// `invalidatedByBiometricEnrollment=true`) is hard-coded **natively** —
  /// this Dart API deliberately exposes no parameters, so no caller can mint
  /// an unbound wrapping key.
  static Future<bool> createWrappingKey() async {
    final result = await _channel.invokeMethod<bool>('createWrappingKey');
    return result ?? false;
  }

  /// Encrypts [password] with the Keystore wrapping key and stores the encrypted
  /// blob in EncryptedSharedPreferences. The raw password is zeroized in native memory.
  ///
  /// This replaces: `await _secureStorage.write(key: _biometricPasswordKey, value: password)`
  static Future<bool> wrapMasterPassword(String password) async {
    final result = await _channel.invokeMethod<bool>('wrapMasterPassword', {
      'password': password,
    });
    return result ?? false;
  }

  /// Decrypts the stored wrapped password via Keystore.
  /// Requires biometric authentication (enforced by Keystore, not Flutter).
  /// Returns the master password as a String – CALLER MUST NOT PERSIST.
  ///
  /// This replaces: `await _secureStorage.read(key: _biometricPasswordKey)`
  static Future<String?> unwrapMasterPassword() async {
    try {
      final result =
          await _channel.invokeMethod<String>('unwrapMasterPassword');
      return result;
    } on PlatformException catch (e) {
      if (e.code == 'AUTH_FAILED') {
        // Biometric authentication failed, timed out, or was cancelled
        return null;
      }
      rethrow;
    }
  }

  /// Checks if a Keystore wrapping key exists (biometric unlock was previously set up).
  static Future<bool> hasWrappingKey() async {
    final result = await _channel.invokeMethod<bool>('hasWrappingKey');
    return result ?? false;
  }

  /// Deletes the Keystore wrapping key and clears stored encrypted password blob.
  /// Call when user disables biometric unlock.
  static Future<bool> deleteWrappingKey() async {
    final result = await _channel.invokeMethod<bool>('deleteWrappingKey');
    return result ?? false;
  }

  // --- Rate-Limited Unlock Attempts ---

  /// Records a failed unlock attempt and returns lockout state.
  /// Lockout follows exponential backoff: 5th → 5s, 6th → 10s, ..., 10+ → 300s.
  static Future<RateLimitState> recordFailedUnlockAttempt() async {
    final result = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('recordFailedUnlockAttempt');
    return RateLimitState.fromMap(result ?? {});
  }

  /// Returns current lockout status without recording a new attempt.
  static Future<RateLimitState> getLockoutStatus() async {
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('getLockoutStatus');
    return RateLimitState.fromMap(result ?? {});
  }

  // V-026: there is deliberately NO Dart-callable `resetFailedAttempts`.
  // The counter is cleared only inside native code, as a side-effect of a
  // successful Keystore-authenticated `unwrapMasterPassword`.

  // --- Screen Capture Control ---

  /// Applies the stored screenshot policy at startup (REQ-SCREEN-01).
  /// Default is PROTECTED (`allow_screenshots` absent/false → FLAG_SECURE on).
  /// The Settings toggle only changes the stored value; without this call the
  /// flag would never be set on fresh installs and recents would leak.
  static Future<void> applyStoredScreenshotPolicy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allowed = prefs.getBool('allow_screenshots') ?? false;
      if (allowed) {
        await disableSecureFlag();
      } else {
        await enableSecureFlag();
      }
    } catch (_) {}
  }

  /// Applies FLAG_SECURE to prevent screenshots and screen recording.
  static Future<bool> enableSecureFlag() async {
    final result = await _channel.invokeMethod<bool>('enableSecureFlag');
    return result ?? false;
  }

  /// Disables FLAG_SECURE — **gated natively (V-019)**: the platform refuses
  /// the call unless the user's stored screenshot policy allows capture and
  /// returns `false` here instead of throwing, so a denied call always
  /// leaves the flag ON (fail closed).
  static Future<bool> disableSecureFlag() async {
    try {
      final result = await _channel.invokeMethod<bool>('disableSecureFlag');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // --- Environment Integrity ---

  /// Checks for compromised environment indicators (dev options, accessibility overlays).
  static Future<({bool isCompromised, List<String> findings})>
      auditEnvironment() async {
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('auditEnvironment');
    if (result == null) return (findings: <String>[], isCompromised: false);

    final rawFindings = (result['findings'] as List<dynamic>?) ?? [];
    return (
      isCompromised: result['isCompromised'] == true,
      findings: rawFindings.map((e) => e.toString()).toList(),
    );
  }

  // --- Secure Clipboard ---

  /// V-017: writes the clip natively so it carries
  /// `ClipDescription.EXTRA_IS_SENSITIVE` — Android 12+/13+ then masks it in
  /// the clipboard preview and assistant suggestions. Plain
  /// `Clipboard.setData` cannot express that flag.
  static Future<bool> setClipboardText(String text) async {
    final result =
        await _channel.invokeMethod<bool>('setClipboard', {'text': text});
    return result ?? false;
  }

  /// Clears the system clipboard immediately.
  static Future<bool> clearClipboard() async {
    final result = await _channel.invokeMethod<bool>('clearClipboard');
    return result ?? false;
  }
}

/// Represents the lockout state after failed unlock attempts.
class RateLimitState {
  final int attemptCount;
  final int lockoutRemainingMs;
  final bool isLockedOut;

  const RateLimitState({
    required this.attemptCount,
    required this.lockoutRemainingMs,
    required this.isLockedOut,
  });

  factory RateLimitState.fromMap(Map<dynamic, dynamic> map) {
    return RateLimitState(
      attemptCount: (map['attemptCount'] as num?)?.toInt() ?? 0,
      lockoutRemainingMs: (map['lockoutRemainingMs'] as num?)?.toInt() ?? 0,
      isLockedOut: map['isLockedOut'] == true,
    );
  }
}
