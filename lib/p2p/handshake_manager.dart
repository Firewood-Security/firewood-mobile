// p2p/handshake_manager.dart
// Ephemeral X25519 ECDH + HKDF-SHA256 + ChaCha20/Poly1305 session security

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'p2p_failures.dart';

/// Manages ephemeral ECDH handshakes and session key derivation.
/// No persistent state. All keys are destroyed on dispose().
class HandshakeManager {
  final X25519 _x25519 = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final Chacha20 _chacha = Chacha20.poly1305Aead();

  SimpleKeyPair? _ephemeralKeyPair;
  PublicKey? _peerPublicKey;
  SecretKey? _sessionKey;

  /// Generate a fresh ephemeral X25519 keypair for this session
  Future<void> generateKeyPair() async {
    try {
      _ephemeralKeyPair = await _x25519.newKeyPair();
    } catch (e) {
      throw HandshakeFailure('Failed to generate X25519 keypair', cause: e);
    }
  }

  /// Get the public key bytes for transmission during handshake
  Future<Uint8List> publicKeyBytes() async {
    if (_ephemeralKeyPair == null) {
      throw const HandshakeFailure('KeyPair has not been generated');
    }
    try {
      final pk = await _ephemeralKeyPair!.extractPublicKey();
      return Uint8List.fromList(pk.bytes);
    } catch (e) {
      throw HandshakeFailure('Failed to extract public key bytes', cause: e);
    }
  }

  /// Receive and parse peer's public key
  void setPeerPublicKeyBytes(Uint8List peerPublicKeyBytes) {
    if (peerPublicKeyBytes.length != 32) {
      throw const HandshakeFailure('Invalid peer public key size. Expected 32 bytes.');
    }
    _peerPublicKey = SimplePublicKey(peerPublicKeyBytes, type: KeyPairType.x25519);
  }

  /// Perform ECDH shared secret derivation and derive HKDF session key
  Future<SecretKey> deriveSessionKey({String infoStr = 'firewood-p2p-v1'}) async {
    if (_ephemeralKeyPair == null) {
      throw const HandshakeFailure('Local KeyPair missing for handshake');
    }
    if (_peerPublicKey == null) {
      throw const HandshakeFailure('Peer public key missing for handshake');
    }

    try {
      // 1. ECDH Shared Secret
      final sharedSecret = await _x25519.sharedSecretKey(
        keyPair: _ephemeralKeyPair!,
        remotePublicKey: _peerPublicKey!,
      );

      // 2. HKDF-SHA256 Derivation
      final salt = utf8.encode('firewood-p2p-salt-v1');
      final info = utf8.encode(infoStr);

      _sessionKey = await _hkdf.deriveKey(
        secretKey: sharedSecret,
        nonce: salt,
        info: info,
      );

      return _sessionKey!;
    } catch (e) {
      throw CryptoFailure('Failed to derive ECDH/HKDF session key', cause: e);
    }
  }

  /// Encrypt payload using the session key via ChaCha20-Poly1305
  Future<SecretBox> encryptPayload(Uint8List plaintext) async {
    if (_sessionKey == null) {
      throw const CryptoFailure('Session key not established');
    }

    try {
      final nonce = _chacha.newNonce();
      final secretBox = await _chacha.encrypt(
        plaintext,
        secretKey: _sessionKey!,
        nonce: nonce,
      );
      return secretBox;
    } catch (e) {
      throw CryptoFailure('Failed to encrypt session payload', cause: e);
    }
  }

  /// Decrypt payload using the session key via ChaCha20-Poly1305
  Future<Uint8List> decryptPayload(SecretBox secretBox) async {
    if (_sessionKey == null) {
      throw const CryptoFailure('Session key not established');
    }

    try {
      final clearBytes = await _chacha.decrypt(
        secretBox,
        secretKey: _sessionKey!,
      );
      return Uint8List.fromList(clearBytes);
    } catch (e) {
      throw CryptoFailure('Failed to decrypt session payload - integrity check failed', cause: e);
    }
  }

  /// Securely destroy all ephemeral keys and state
  void dispose() {
    _ephemeralKeyPair = null;
    _peerPublicKey = null;
    _sessionKey = null;
  }
}
