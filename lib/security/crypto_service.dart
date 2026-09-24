// security/crypto_service.dart
// Core cryptography service using cryptography package
// Argon2id key derivation + XChaCha20-Poly1305 authenticated encryption

import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  // Argon2id parameters (OWASP recommendations for mobile)
  static const int _memory = 65536; // 64 MB
  static const int _iterations = 3;
  static const int _parallelism = 4;
  static const int _hashLength = 32; // 256-bit key for XChaCha20-Poly1305
  static const int _saltLength = 16; // 128-bit salt

  final Argon2id _argon2 = Argon2id(
    memory: _memory,
    iterations: _iterations,
    parallelism: _parallelism,
    hashLength: _hashLength,
  );

  final Cipher _xchacha = Xchacha20.poly1305Aead();

  /// Generates a cryptographically secure 16-byte salt for Argon2id.
  /// Call once at vault creation and store the salt in plaintext.
  List<int> generateSalt() {
    final random = Random.secure();
    return List<int>.generate(_saltLength, (_) => random.nextInt(256));
  }

  /// Derives a 256-bit SecretKey from password and salt using Argon2id.
  /// The derived key exists only in memory - never persist it.
  Future<SecretKey> deriveKey(String password, List<int> salt) async {
    final secretBox = await _argon2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return secretBox;
  }

  /// Derives a domain-separated subkey from a master key using HKDF-Expand (RFC 5869).
  Future<SecretKey> deriveSubkey(SecretKey masterKey, String infoString) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return await hkdf.deriveKey(
      secretKey: masterKey,
      nonce: const [],
      info: utf8.encode(infoString),
    );
  }

  /// Encrypts plaintext using XChaCha20-Poly1305 with a fresh 24-byte nonce.
  /// Returns ciphertext (including Poly1305 MAC tag) and nonce.
  /// Nonce is NOT secret, store alongside ciphertext.
  /// Never reuse a nonce with the same key.
  Future<({List<int> ciphertext, List<int> nonce})> encrypt(
    List<int> plaintext,
    SecretKey key,
  ) async {
    final nonce = _xchacha.newNonce();
    final secretBox = await _xchacha.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
    );
    final combinedCiphertext = [
      ...secretBox.cipherText,
      ...secretBox.mac.bytes
    ];
    return (ciphertext: combinedCiphertext, nonce: secretBox.nonce);
  }

  /// Decrypts ciphertext using XChaCha20-Poly1305 with the provided nonce and key.
  /// Throws SecretBoxAuthenticationError / Exception if authentication fails.
  Future<List<int>> decrypt(
    List<int> ciphertext,
    List<int> nonce,
    SecretKey key,
  ) async {
    if (ciphertext.length < 16) {
      throw SecretBoxAuthenticationError();
    }
    final cipherTextOnly = ciphertext.sublist(0, ciphertext.length - 16);
    final macBytes = ciphertext.sublist(ciphertext.length - 16);
    final secretBox = SecretBox(
      cipherTextOnly,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    final clearText = await _xchacha.decrypt(secretBox, secretKey: key);
    return clearText;
  }

  /// Convenience: encrypt a UTF-8 string to bytes.
  Future<({List<int> ciphertext, List<int> nonce})> encryptString(
    String plaintext,
    SecretKey key,
  ) async {
    return encrypt(utf8.encode(plaintext), key);
  }

  /// Convenience: decrypt bytes to UTF-8 string.
  Future<String> decryptString(
    List<int> ciphertext,
    List<int> nonce,
    SecretKey key,
  ) async {
    final bytes = await decrypt(ciphertext, nonce, key);
    return utf8.decode(bytes);
  }
}
