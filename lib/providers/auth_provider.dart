// providers/auth_provider.dart
// Riverpod providers for auth, single-vault state, and burner service.

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/vault_service.dart';
import '../services/burner_service.dart';
import '../security/crypto_service.dart';

// StateProvider holds the SecretKey in memory only.
// Setting to null = locked vault. Never persist to disk!
final authProvider = StateProvider<SecretKey?>((ref) => null);

// Convenience provider for UI to check unlock state
final isUnlockedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) != null;
});

// Vault service provider
final vaultServiceProvider = Provider<VaultService>((ref) {
  return VaultService();
});

// Burner service provider
final burnerServiceProvider = Provider<BurnerService>((ref) {
  return BurnerService();
});

// Crypto service provider
final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

// Biometric Auth setting provider
final biometricAuthEnabledProvider = StateNotifierProvider<BiometricAuthNotifier, bool>((ref) {
  return BiometricAuthNotifier();
});

class BiometricAuthNotifier extends StateNotifier<bool> {
  BiometricAuthNotifier() : super(false) {
    _load();
  }

  static const _secureStorage = FlutterSecureStorage();
  static const _biometricPasswordKey = 'biometric_master_password';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('biometric_auth_enabled') ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_auth_enabled', enabled);
    state = enabled;

    if (!enabled) {
      try {
        await _secureStorage.delete(key: _biometricPasswordKey);
      } catch (_) {}
    }
  }
}
