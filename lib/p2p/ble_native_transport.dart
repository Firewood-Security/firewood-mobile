// p2p/ble_native_transport.dart
// Native Android BLE transport implementing P2PTransport interface.
//
// Uses BleP2PBridge (native Kotlin BLE) under the hood instead of
// flutter_nearby_connections_plus. Keeps X25519 + XChaCha20-Poly1305
// handshake in Dart via P2PCryptoSession.
//
// This transport fixes:
//  - P2P2: base64 key encoding corruption (sends raw bytes)
//  - P2P1: re-enables SAS code display + verification

import 'dart:async';
import 'dart:typed_data';
import 'transport_adapter.dart';
import 'crypto_transport.dart';
import 'p2p_failures.dart';
import '../services/ble_p2p_bridge.dart';

class BleNativeTransport implements P2PTransport {
  final StreamController<Map<String, Uint8List>> _incomingDataController =
      StreamController<Map<String, Uint8List>>.broadcast();

  String? _connectedDeviceId;
  String? _ourDeviceId; // Advertiser: our device ID for self-filtering
  bool _isInit = false;

  // Per-peer crypto sessions
  final Map<String, P2PCryptoSession> _cryptoSessions = {};

  // Stream subscriptions
  StreamSubscription? _connectionSub;
  StreamSubscription? _dataSub;

  @override
  Future<void> init() async {
    if (_isInit) return;
    await BleP2PBridge.init();
    _isInit = true;
  }

  @override
  Future<void> startDiscovery({required Function(DiscoveredPeer peer) onPeerFound}) async {
    await init();
    try {
      // Listen for discovered devices
      BleP2PBridge.discoveryStream.listen((event) {
        if (event['event'] == 'discovered') {
          final deviceId = event['deviceId'] as String;
          final deviceName = event['deviceName'] as String? ?? 'Firewood Device';

          if (deviceId == _ourDeviceId) return; // Skip self

          onPeerFound(DiscoveredPeer(
            id: deviceId,
            name: deviceName,
            transportType: 'ble_native',
            deviceType: 'phone',
          ));
        }
      });

      await BleP2PBridge.startScan();
    } catch (e) {
      throw TransportFailure('Failed to start BLE discovery', cause: e);
    }
  }

  @override
  Future<void> startAdvertising({required Function(DiscoveredPeer peer) onPeerConnected}) async {
    await init();

    // Listen for connection events
    _connectionSub?.cancel();
    _connectionSub = BleP2PBridge.connectionStream.listen((event) {
      if (event['event'] == 'connected' && event['role'] == 'receiver') {
        final deviceId = event['deviceId'] as String;
        final deviceName = event['deviceName'] as String? ?? 'Firewood Device';
        _connectedDeviceId = deviceId;

        onPeerConnected(DiscoveredPeer(
          id: deviceId,
          name: deviceName,
          transportType: 'ble_native',
          deviceType: 'phone',
        ));
      }
    });

    // Listen for incoming data
    _dataSub?.cancel();
    _dataSub = BleP2PBridge.dataStream.listen((event) {
      final deviceId = event['deviceId'] as String;
      final data = event['data'] as Uint8List?;
      if (deviceId.isNotEmpty && data != null) {
        _incomingDataController.add({deviceId: data});
      }
    });

    try {
      await BleP2PBridge.startAdvertise();
    } catch (e) {
      throw TransportFailure('Failed to start BLE advertising', cause: e);
    }
  }

  @override
  Future<void> connect(DiscoveredPeer peer) async {
    try {
      await BleP2PBridge.connectDevice(peer.id);
      _connectedDeviceId = peer.id;

      // Listen for incoming data from connected device
      _dataSub?.cancel();
      _dataSub = BleP2PBridge.dataStream.listen((event) {
        final deviceId = event['deviceId'] as String;
        final data = event['data'] as Uint8List?;
        if (deviceId == peer.id && data != null) {
          _incomingDataController.add({peer.id: data});
        }
      });
    } catch (e) {
      throw TransportFailure('Failed to connect to ${peer.name}', cause: e);
    }
  }

  @override
  Future<void> accept(DiscoveredPeer peer) async {
    // BLE GATT server automatically accepts connections – no explicit accept needed
  }

  @override
  Future<void> send(String peerId, Uint8List data) async {
    // BLE MTU negotiated to 512, safe payload is ~100 bytes per write.
    const chunkSize = 100;
    for (int offset = 0; offset < data.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, data.length);
      final chunk = data.sublist(offset, end);
      final success = await BleP2PBridge.sendData(peerId, Uint8List.fromList(chunk));
      if (!success) {
        throw TransportFailure('BLE send failed at offset $offset of ${data.length} bytes');
      }
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Send encrypted payload with full X25519 handshake over native BLE.
  /// Returns SAS code for user verification (FIX: SAS was removed in NearbyTransport).
  @override
  Future<String> sendPayload(DiscoveredPeer peer, Uint8List data) async {
    await connect(peer);

    final session = P2PCryptoSession();
    _cryptoSessions[peer.id] = session;

    try {
      // 1. Generate our ephemeral X25519 keypair
      final ourPubKey = await session.initializeAsInitiator();

      // 2. Send raw 32-byte public key (FIX: no base64 encoding, raw bytes)
      await send(peer.id, ourPubKey);

      // 3. Receive peer's 32-byte public key
      final compat = Completer<Uint8List>();
      final sub = receiveStream(peer.id).listen((data) {
        if (!compat.isCompleted) compat.complete(data);
      });

      final peerPubKey = await compat.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutFailure('Timed out waiting for peer public key'),
      );
      await sub.cancel();

      session.setPeerPublicKey(peerPubKey);

      // 4. Complete handshake (derive session key + SAS code)
      await session.completeHandshake();

      // 5. Encrypt payload
      final encryptedPacket = await session.encrypt(data);

      // 6. Send encrypted wire packet
      await send(peer.id, encryptedPacket);

      // Return SAS code for user verification (FIX: SAS was removed in NearbyTransport)
      return session.sasCode ?? '00000';
    } catch (e) {
      _cryptoSessions.remove(peer.id);
      rethrow;
    }
  }

  /// Receive and decrypt payload on the receiver (advertiser) side.
  @override
  Future<Uint8List> receiveEncryptedPayload(String peerId) async {
    var session = _cryptoSessions[peerId];

    if (session == null) {
      session = P2PCryptoSession();
      _cryptoSessions[peerId] = session;

      // 1. Wait for peer's public key (first 32 bytes, single chunk)
      final compat = Completer<Uint8List>();
      final sub = receiveStream(peerId).listen((data) {
        if (!compat.isCompleted) compat.complete(data);
      });

      final peerPubKey = await compat.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutFailure('Timed out waiting for peer public key'),
      );
      await sub.cancel();

      // 2. Initialize as responder (generates our keypair, returns our pubkey)
      final ourPubKey = await session.initializeAsResponder(peerPubKey);

      // 3. Send our raw 32-byte public key (FIX: no base64 encoding)
      await send(peerId, ourPubKey);

      // 4. Complete handshake
      await session.completeHandshake();
    }

    // 5. Accumulate chunks to reassemble full encrypted packet (with 4-byte length prefix)
    final stream = receiveStream(peerId);
    final pktCompat = Completer<Uint8List>();
    Uint8List buffer = Uint8List(0);

    late StreamSubscription sub2;
    sub2 = stream.listen((data) {
      buffer = Uint8List.fromList([...buffer, ...data]);

      // Check if we have at least the length prefix (4 bytes)
      if (buffer.length >= LENGTH_PREFIX_SIZE) {
        final lenBytes = buffer.sublist(0, LENGTH_PREFIX_SIZE);
        final bd = ByteData.sublistView(lenBytes);
        final packetLen = bd.getUint32(0, Endian.big);
        final totalExpected = LENGTH_PREFIX_SIZE + packetLen;

        if (buffer.length >= totalExpected) {
          final result = buffer.sublist(0, totalExpected);
          buffer = buffer.sublist(totalExpected);
          sub2.cancel();
          pktCompat.complete(result);
        }
      }
    });

    final encryptedPacket = await pktCompat.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw TimeoutFailure('Timed out waiting for encrypted payload'),
    );

    // 6. Decrypt
    final decrypted = await session.decrypt(encryptedPacket);
    _cryptoSessions.remove(peerId);
    return decrypted;
  }

  @override
  Stream<Uint8List> receiveStream(String peerId) {
    return _incomingDataController.stream
        .where((map) => map.containsKey(peerId))
        .map((map) => map[peerId]!);
  }

  @override
  Future<void> disconnect() async {
    await _connectionSub?.cancel();
    await _dataSub?.cancel();
    if (_connectedDeviceId != null) {
      await BleP2PBridge.disconnectDevice(_connectedDeviceId!);
    }
    await BleP2PBridge.shutdown();

    for (final session in _cryptoSessions.values) {
      session.dispose();
    }
    _cryptoSessions.clear();
    _connectedDeviceId = null;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _incomingDataController.close();
  }
}
