// security/crypto_service.dart
// Core cryptography service using cryptography package.
// Argon2id key derivation + HKDF subkey separation + XChaCha20-Poly1305 AEAD.
//
// V-028: HKDF purpose labels prevent cross-purpose key reuse. Every stored
// encryption picks exactly one purpose, so ciphertext written for one
// purpose can never be validated under another even though the parent key
// is shared. AAD record binding ties ciphertext to its record ID, so
// copying ciphertext between records breaks the MAC.

import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import '../debug/crypto_debug.dart';

class CryptoService {
  // Argon2id parameters (OWASP recommendations for mobile)
  static const int _memory = 65536; // 64 MB
  static const int _iterations = 3;
  static const int _parallelism = 4;
  static const int _hashLength = 32; // 256-bit key for XChaCha20-Poly1305
  static const int _saltLength = 16; // 128-bit salt
  static const int _nonceLength = 24; // XChaCha20-Poly1305 nonce
  static const int _macLength = 16; // Poly1305 tag

  // V-028: HKDF purpose labels. Every stored encryption picks exactly one.
  static const String purposeMekWrap = 'firewood/vault/mek-wrap/v1';
  static const String purposeVerifier = 'firewood/vault/verifier/v1';
  static const String purposeItems = 'firewood/vault/items/v1';
  static const String purposeQuickUnlock = 'firewood/vault/quick-unlock/v1';

  /// V-028: record-binding context for vault items. The ciphertext is only
  /// ever valid inside the record whose id is embedded here, so copying a
  /// record's ciphertext+nonce into a different record breaks the MAC.
  static List<int> itemAad(String itemId) =>
      utf8.encode('firewood/item/v1:$itemId');

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

  /// Cryptographically secure random bytes of given [length].
  List<int> generateRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Derives a 256-bit SecretKey from password and salt using Argon2id.
  /// The derived key exists only in memory - never persist it.
  Future<SecretKey> deriveKey(String password, List<int> salt) async {
    return CryptoDebug.trace('argon2id.deriveKey', () async {
      final secretBox = await _argon2.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );
      return secretBox;
    }, meta: {'salt_len': salt.length});
  }

  /// Derives a domain-separated subkey from a master key using HKDF-Expand (RFC 5869).
  Future<SecretKey> deriveSubkey(SecretKey masterKey, String infoString) async {
    return CryptoDebug.trace('hkdf.deriveSubkey', () async {
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      return await hkdf.deriveKey(
        secretKey: masterKey,
        nonce: const [],
        info: utf8.encode(infoString),
      );
    }, meta: {'purpose': infoString.split('/').last});
  }

  /// Encrypts plaintext using XChaCha20-Poly1305 with a fresh 24-byte nonce.
  /// [aad] (V-028) is authenticated but not encrypted — pass the header or
  /// record identity so the ciphertext is bound to its context.
  Future<({List<int> ciphertext, List<int> nonce})> encrypt(
    List<int> plaintext,
    SecretKey key, {
    List<int> aad = const [],
  }) async {
    return CryptoDebug.trace('xchacha20.encrypt', () async {
      final nonce = _xchacha.newNonce();
      final secretBox = await _xchacha.encrypt(
        plaintext,
        secretKey: key,
        nonce: nonce,
        aad: aad,
      );
      final combinedCiphertext = [
        ...secretBox.cipherText,
        ...secretBox.mac.bytes
      ];
      return (ciphertext: combinedCiphertext, nonce: secretBox.nonce);
    }, meta: {
      'pt_len': plaintext.length,
      'aad_len': aad.length,
    });
  }

  /// Decrypts ciphertext using XChaCha20-Poly1305 with the provided nonce and key.
  /// [aad] must byte-match the value the ciphertext was encrypted with.
  /// Throws SecretBoxAuthenticationError / Exception if authentication fails.
  Future<List<int>> decrypt(
    List<int> ciphertext,
    List<int> nonce,
    SecretKey key, {
    List<int> aad = const [],
  }) async {
    return CryptoDebug.trace('xchacha20.decrypt', () async {
      if (ciphertext.length < _macLength) {
        throw SecretBoxAuthenticationError();
      }
      if (nonce.length != _nonceLength) {
        throw SecretBoxAuthenticationError();
      }
      final cipherTextOnly =
          ciphertext.sublist(0, ciphertext.length - _macLength);
      final macBytes = ciphertext.sublist(ciphertext.length - _macLength);
      final secretBox = SecretBox(
        cipherTextOnly,
        nonce: nonce,
        mac: Mac(macBytes),
      );
      final clearText =
          await _xchacha.decrypt(secretBox, secretKey: key, aad: aad);
      return clearText;
    }, meta: {
      'ct_len': ciphertext.length,
      'aad_len': aad.length,
    });
  }

  /// V-028: decrypts a record written by either format:
  ///   * current  — HKDF [purpose] subkey of [parentKey] with [aad] bound, or
  ///   * pre-V-028 — the raw [parentKey] with no associated data.
  ///
  /// The fallback cannot launder tampering: an AAD-bound box only verifies
  /// under its own AAD and key (the MAC covers both), so ciphertext moved to
  /// another record, or rewritten from an old-format decryptor, still fails.
  Future<List<int>> decryptBoundOrLegacy(
    List<int> ciphertext,
    List<int> nonce,
    SecretKey parentKey, {
    required String purpose,
    List<int> aad = const [],
  }) async {
    final subkey = await deriveSubkey(parentKey, purpose);
    try {
      return await decrypt(ciphertext, nonce, subkey, aad: aad);
    } on SecretBoxAuthenticationError {
      return await decrypt(ciphertext, nonce, parentKey);
    }
  }

  /// String form of [decryptBoundOrLegacy].
  Future<String> decryptStringBoundOrLegacy(
    List<int> ciphertext,
    List<int> nonce,
    SecretKey parentKey, {
    required String purpose,
    List<int> aad = const [],
  }) async =>
      utf8.decode(await decryptBoundOrLegacy(ciphertext, nonce, parentKey,
          purpose: purpose, aad: aad));

  /// Convenience: encrypt a UTF-8 string to bytes.
  Future<({List<int> ciphertext, List<int> nonce})> encryptString(
    String plaintext,
    SecretKey key, {
    List<int> aad = const [],
  }) async {
    return encrypt(utf8.encode(plaintext), key, aad: aad);
  }

  /// Convenience: decrypt bytes to UTF-8 string.
  Future<String> decryptString(
    List<int> ciphertext,
    List<int> nonce,
    SecretKey key, {
    List<int> aad = const [],
  }) async {
    final bytes = await decrypt(ciphertext, nonce, key, aad: aad);
    return utf8.decode(bytes);
  }
}
