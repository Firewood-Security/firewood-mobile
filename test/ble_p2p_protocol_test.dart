// test/ble_p2p_protocol_test.dart
// Unit tests for Firewood BLE P2P Protocol (2-node limit, 1-50KB payload bounds, role switching)

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:firewood/p2p/transport_adapter.dart';
import 'package:firewood/p2p/crypto_transport.dart';
import 'package:firewood/p2p/p2p_failures.dart';

void main() {
  group('Firewood BLE P2P Protocol Tests', () {
    test('Verify max 2 nodes limit constant', () {
      expect(TransportManager.maxNodes, equals(2));
      expect(TransportManager.minPayloadBytes, equals(1024));
      expect(TransportManager.maxPayloadBytes, equals(500 * 1024 * 1024));
    });

    test('Payload size exceeding 500 MB throws TransportFailure', () async {
      final transport = TransportManager();
      final oversizedData = Uint8List(501 * 1024 * 1024); // 501 MB

      expect(
        () => transport.send('peer-123', oversizedData),
        throwsA(isA<TransportFailure>()),
      );
    });

    test('Role switching between Listener and Client', () async {
      final transport = TransportManager();
      expect(transport.currentRole, equals(P2PRole.listener));

      await transport.switchRole(P2PRole.client);
      expect(transport.currentRole, equals(P2PRole.client));

      await transport.switchRole(P2PRole.listener);
      expect(transport.currentRole, equals(P2PRole.listener));
    });

    test('X25519 key exchange creates 32-byte public key', () async {
      final (pubKey, keyPair) = await performX25519KeyExchange();
      expect(pubKey.length, equals(32));
      expect(keyPair, isNotNull);
    });
  });
}
