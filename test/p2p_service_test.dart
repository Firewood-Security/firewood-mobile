// test/p2p_service_test.dart
// Unit tests for Firewood P2P transfer system cryptographic handshake and models

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firewood/p2p/handshake_manager.dart';
import 'package:firewood/p2p/p2p_failures.dart';
import 'package:firewood/p2p/transfer_models.dart';

void main() {
  group('HandshakeManager Cryptographic Unit Tests', () {
    late HandshakeManager senderHandshake;
    late HandshakeManager receiverHandshake;

    setUp(() {
      senderHandshake = HandshakeManager();
      receiverHandshake = HandshakeManager();
    });

    tearDown(() {
      senderHandshake.dispose();
      receiverHandshake.dispose();
    });

    test('X25519 ECDH keypair generation returns 32-byte public key', () async {
      await senderHandshake.generateKeyPair();
      final pubKey = await senderHandshake.publicKeyBytes();
      expect(pubKey.length, equals(32));
    });

    test('Sender and Receiver derive identical session key via ECDH + HKDF-SHA256', () async {
      // 1. Both generate keypairs
      await senderHandshake.generateKeyPair();
      await receiverHandshake.generateKeyPair();

      final senderPubKey = await senderHandshake.publicKeyBytes();
      final receiverPubKey = await receiverHandshake.publicKeyBytes();

      // 2. Exchange public keys
      senderHandshake.setPeerPublicKeyBytes(receiverPubKey);
      receiverHandshake.setPeerPublicKeyBytes(senderPubKey);

      // 3. Derive session keys
      final senderSessionKey = await senderHandshake.deriveSessionKey();
      final receiverSessionKey = await receiverHandshake.deriveSessionKey();

      final senderKeyBytes = await senderSessionKey.extractBytes();
      final receiverKeyBytes = await receiverSessionKey.extractBytes();

      expect(senderKeyBytes, equals(receiverKeyBytes));
      expect(senderKeyBytes.length, equals(32)); // 256-bit session key
    });

    test('ChaCha20-Poly1305 payload encryption and decryption roundtrip works', () async {
      await senderHandshake.generateKeyPair();
      await receiverHandshake.generateKeyPair();

      final senderPubKey = await senderHandshake.publicKeyBytes();
      final receiverPubKey = await receiverHandshake.publicKeyBytes();

      senderHandshake.setPeerPublicKeyBytes(receiverPubKey);
      receiverHandshake.setPeerPublicKeyBytes(senderPubKey);

      await senderHandshake.deriveSessionKey();
      await receiverHandshake.deriveSessionKey();

      final originalData = utf8.encode('FIREWOOD_CONFIDENTIAL_PAYLOAD_TEST');
      final secretBox = await senderHandshake.encryptPayload(Uint8List.fromList(originalData));

      final decryptedBytes = await receiverHandshake.decryptPayload(secretBox);
      expect(utf8.decode(decryptedBytes), equals('FIREWOOD_CONFIDENTIAL_PAYLOAD_TEST'));
    });

    test('Decryption fails with CryptoFailure if secretBox integrity is tampered', () async {
      await senderHandshake.generateKeyPair();
      await receiverHandshake.generateKeyPair();

      senderHandshake.setPeerPublicKeyBytes(await receiverHandshake.publicKeyBytes());
      receiverHandshake.setPeerPublicKeyBytes(await senderHandshake.publicKeyBytes());

      await senderHandshake.deriveSessionKey();
      await receiverHandshake.deriveSessionKey();

      final originalData = utf8.encode('TAMPER_TEST_DATA');
      final secretBox = await senderHandshake.encryptPayload(Uint8List.fromList(originalData));

      // Tamper ciphertext
      final tamperedCipher = List<int>.from(secretBox.cipherText);
      tamperedCipher[0] ^= 0xFF;

      final tamperedBox = SecretBox(
        tamperedCipher,
        nonce: secretBox.nonce,
        mac: secretBox.mac,
      );

      expect(
        () async => await receiverHandshake.decryptPayload(tamperedBox),
        throwsA(isA<CryptoFailure>()),
      );
    });
  });

  group('TransferModels Serialization Unit Tests', () {
    test('HandshakePacket serializes and deserializes correctly', () {
      const packet = HandshakePacket(
        deviceId: 'device-123',
        deviceName: 'Alice Phone',
        publicKeyBase64: '[1,2,3,4,5]',
        timestamp: 1600000000,
      );

      final jsonStr = packet.serialize();
      final restored = HandshakePacket.deserialize(jsonStr);

      expect(restored.deviceId, equals('device-123'));
      expect(restored.deviceName, equals('Alice Phone'));
      expect(restored.publicKeyBase64, equals('[1,2,3,4,5]'));
    });

    test('TransferPacket serializes and deserializes correctly', () {
      const packet = TransferPacket(
        transferId: 'trans-999',
        encryptedPayloadBase64: '[10,20,30]',
        nonceBase64: '[1,2,3]',
        macBase64: '[4,5,6]',
      );

      final jsonStr = packet.serialize();
      final restored = TransferPacket.deserialize(jsonStr);

      expect(restored.transferId, equals('trans-999'));
      expect(restored.encryptedPayloadBase64, equals('[10,20,30]'));
    });
  });
}
