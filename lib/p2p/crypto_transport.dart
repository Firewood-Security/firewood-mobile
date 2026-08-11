import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Protocol version for wire compatibility
const int P2P_PROTOCOL_VERSION = 1;

/// Magic bytes for protocol identification
const List<int> P2P_MAGIC = [0x46, 0x57, 0x50, 0x32]; // 'FWP2'

/// Standard ports
const int DISCOVERY_PORT = 52719;
const int TCP_PORT = 52720;

/// Payload size limits (matching max user setting)
const int MIN_PAYLOAD_SIZE = 1024;               // 1 KB
const int MAX_PAYLOAD_SIZE = 500 * 1024 * 1024;  // 500 MB

/// X25519 key size
const int X25519_KEY_SIZE = 32;

/// XChaCha20-Poly1305 nonce size
const int XCHACHA_NONCE_SIZE = 24;

/// Length prefix size (4 bytes, big-endian)
const int LENGTH_PREFIX_SIZE = 4;

/// Derives session key using HKDF-SHA256 from X25519 shared secret (RFC 5869)
Future<SecretKey> deriveSessionKey(SecretKey sharedSecret) async {
  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final derived = await hkdf.deriveKey(
    secretKey: sharedSecret,
    nonce: const [],
    info: utf8.encode('FIREWOOD_P2P_SESSION_V1'),
  );
  return derived;
}


/// Performs X25519 ECDH key exchange
/// Returns (ourPublicKey, ourKeyPair)
Future<(Uint8List, SimpleKeyPair)> performX25519KeyExchange() async {
  final x25519 = X25519();
  final keyPair = await x25519.newKeyPair();
  final ourPubKey = await keyPair.extractPublicKey();
  final ourPubBytes = Uint8List.fromList(ourPubKey.bytes);
  return (ourPubBytes, keyPair);
}

/// Computes shared secret from our keypair and peer's public key
Future<SecretKey> computeSharedSecret(
  SimpleKeyPair ourKeyPair, 
  Uint8List peerPublicKeyBytes
) async {
  final x25519 = X25519();
  final peerPublicKey = SimplePublicKey(peerPublicKeyBytes, type: KeyPairType.x25519);
  return await x25519.sharedSecretKey(keyPair: ourKeyPair, remotePublicKey: peerPublicKey);
}

/// Encrypts payload using XChaCha20-Poly1305 with session key
/// Returns (nonce, ciphertextWithMac) where ciphertextWithMac = ciphertext || mac (concatenated)
Future<(Uint8List, Uint8List)> encryptPayload(Uint8List plaintext, SecretKey sessionKey) async {
  final xchacha = Xchacha20.poly1305Aead();
  final nonce = xchacha.newNonce();
  final secretBox = await xchacha.encrypt(
    plaintext,
    secretKey: sessionKey,
    nonce: nonce,
  );
  
  // concatenation(nonce: false) returns ciphertext || mac
  final ciphertextWithMac = secretBox.concatenation(nonce: false);
  return (Uint8List.fromList(nonce), Uint8List.fromList(ciphertextWithMac));
}

/// Decrypts payload using XChaCha20-Poly1305 with session key
Future<Uint8List> decryptPayload(
  Uint8List nonce,
  Uint8List ciphertextWithMac,
  SecretKey sessionKey
) async {
  final xchacha = Xchacha20.poly1305Aead();
  
  // Reconstruct SecretBox from concatenated ciphertext+mac
  final fullPayload = Uint8List(nonce.length + ciphertextWithMac.length);
  fullPayload.setAll(0, nonce);
  fullPayload.setAll(nonce.length, ciphertextWithMac);
  
  final secretBox = SecretBox.fromConcatenation(
    fullPayload,
    nonceLength: XCHACHA_NONCE_SIZE,
    macLength: 16,
  );
  
  final decrypted = await xchacha.decrypt(
    secretBox,
    secretKey: sessionKey,
  );
  return Uint8List.fromList(decrypted);
}

/// Builds the encrypted wire packet: [4-byte length][24-byte nonce][ciphertext||mac]
/// Length = 24 + ciphertextWithMac.length
Uint8List buildWirePacket(Uint8List nonce, Uint8List ciphertextWithMac) {
  final totalLen = XCHACHA_NONCE_SIZE + ciphertextWithMac.length;
  if (totalLen > MAX_PAYLOAD_SIZE) {
    throw ArgumentError('Packet size ($totalLen) exceeds maximum $MAX_PAYLOAD_SIZE bytes');
  }
  
  final packet = Uint8List(LENGTH_PREFIX_SIZE + totalLen);
  
  // 4-byte big-endian length prefix
  final lenBytes = ByteData(4);
  lenBytes.setUint32(0, totalLen, Endian.big);
  packet.setAll(0, lenBytes.buffer.asUint8List());
  
  // 24-byte nonce
  packet.setAll(LENGTH_PREFIX_SIZE, nonce);
  
  // Ciphertext + MAC
  packet.setAll(LENGTH_PREFIX_SIZE + XCHACHA_NONCE_SIZE, ciphertextWithMac);
  
  return packet;
}

/// Parses wire packet: [4-byte length][24-byte nonce][ciphertext||mac]
/// Returns (nonce, ciphertextWithMac)
(Uint8List, Uint8List) parseWirePacket(Uint8List packet) {
  if (packet.length < LENGTH_PREFIX_SIZE + XCHACHA_NONCE_SIZE) {
    throw FormatException('Packet too small: ${packet.length} bytes');
  }
  
  final lenBytes = packet.sublist(0, LENGTH_PREFIX_SIZE);
  final bd = ByteData.sublistView(lenBytes);
  final packetLen = bd.getUint32(0, Endian.big);
  
  if (packetLen < XCHACHA_NONCE_SIZE || packetLen > MAX_PAYLOAD_SIZE) {
    throw FormatException('Invalid packet length: $packetLen');
  }
  
  if (packet.length != LENGTH_PREFIX_SIZE + packetLen) {
    throw FormatException('Packet length mismatch: expected ${LENGTH_PREFIX_SIZE + packetLen}, got ${packet.length}');
  }
  
  final nonce = packet.sublist(LENGTH_PREFIX_SIZE, LENGTH_PREFIX_SIZE + XCHACHA_NONCE_SIZE);
  final ciphertextWithMac = packet.sublist(LENGTH_PREFIX_SIZE + XCHACHA_NONCE_SIZE);
  
  return (nonce, ciphertextWithMac);
}

/// Reads exactly [count] bytes from a StreamIterator
class ChunkedDataReader {
  final StreamIterator<Uint8List> iterator;
  Uint8List _buffer = Uint8List(0);

  ChunkedDataReader(this.iterator);

  Future<Uint8List> readExact(int count) async {
    while (_buffer.length < count) {
      if (!await iterator.moveNext()) {
        throw Exception('Stream closed prematurely: expected $count bytes, got ${_buffer.length}');
      }
      final chunk = iterator.current;
      final newBuf = Uint8List(_buffer.length + chunk.length);
      newBuf.setAll(0, _buffer);
      newBuf.setAll(_buffer.length, chunk);
      _buffer = newBuf;
    }

    final result = Uint8List.sublistView(_buffer, 0, count);
    _buffer = Uint8List.sublistView(_buffer, count);
    return result;
  }
}

/// Complete P2P Crypto Session for a single transfer
/// Handles the full X25519 handshake + encryption/decryption + SAS verification
class P2PCryptoSession {
  SimpleKeyPair? _ourKeyPair;
  Uint8List? _ourPublicKey;
  Uint8List? _peerPublicKey;
  SecretKey? _sessionKey;
  String? _sasCode;

  /// Initialize as initiator (sender) - generates our keypair
  Future<Uint8List> initializeAsInitiator() async {
    final result = await performX25519KeyExchange();
    _ourKeyPair = result.$2;
    _ourPublicKey = result.$1;
    return _ourPublicKey!;
  }

  /// Initialize as responder (receiver) - generates our keypair after receiving peer's
  Future<Uint8List> initializeAsResponder(Uint8List peerPubKey) async {
    _peerPublicKey = peerPubKey;
    final result = await performX25519KeyExchange();
    _ourKeyPair = result.$2;
    _ourPublicKey = result.$1;
    return _ourPublicKey!;
  }

  /// Set peer's public key (called by initiator after sending ours)
  void setPeerPublicKey(Uint8List peerPubKey) {
    _peerPublicKey = peerPubKey;
  }

  /// Complete handshake and derive session key + SAS verification code.
  ///
  /// SAS code is derived from SHA-256(session_key || FIREWOOD_SAS_V1 || ourPubKey || peerPubKey)
  /// and displayed as a 5-digit decimal for both users to visually match.
  /// This is the ONLY MITM protection in the P2P protocol – users MUST verify.
  Future<void> completeHandshake() async {
    if (_ourKeyPair == null || _peerPublicKey == null || _ourPublicKey == null) {
      throw StateError('Handshake not properly initialized');
    }

    // Compute shared secret
    final sharedSecret = await computeSharedSecret(_ourKeyPair!, _peerPublicKey!);
    
    // Derive session key via SHA-256 (matching Tauri p2p.rs)
    _sessionKey = await deriveSessionKey(sharedSecret);

    // Compute SAS verification code: SHA-256(session_key || sashash || our_pubkey || peer_pubkey)
    final sessionKeyBytes = await _sessionKey!.extractBytes();
    final sasInput = Uint8List.fromList([
      ...sessionKeyBytes,
      ...'FIREWOOD_SAS_V1'.codeUnits,
      ..._ourPublicKey!,
      ..._peerPublicKey!,
    ]);
    final sasHash = await Sha256().hash(sasInput);
    final sasBytes = sasHash.bytes;
    // 6-digit code: first 6 bytes of hash, each mod 10 → digits 0-9
    final sasDigits = List.generate(6, (i) => (sasBytes[i] % 10).toString()).join();
    _sasCode = sasDigits;
  }

  /// The 6-digit SAS verification code. Both sides compute the same value.
  /// Users must verbally or visually confirm this matches before proceeding.
  String? get sasCode => _sasCode;

  /// Encrypt payload for transmission
  Future<Uint8List> encrypt(Uint8List plaintext) async {
    if (_sessionKey == null) throw StateError('Handshake not completed');
    
    final (nonce, ciphertextWithMac) = await encryptPayload(plaintext, _sessionKey!);
    return buildWirePacket(nonce, ciphertextWithMac);
  }

  /// Decrypt received payload
  Future<Uint8List> decrypt(Uint8List wirePacket) async {
    if (_sessionKey == null) throw StateError('Handshake not completed');
    
    final (nonce, ciphertextWithMac) = parseWirePacket(wirePacket);
    return await decryptPayload(nonce, ciphertextWithMac, _sessionKey!);
  }

  Uint8List? get ourPublicKey => _ourPublicKey;
  Uint8List? get peerPublicKey => _peerPublicKey;
  
  void dispose() {
    _ourKeyPair = null;
    _peerPublicKey = null;
    _ourPublicKey = null;
    _sessionKey = null;
    _sasCode = null;
  }
}