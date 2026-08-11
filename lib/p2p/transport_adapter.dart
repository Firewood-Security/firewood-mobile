import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_nearby_connections_plus/flutter_nearby_connections_plus.dart';
import '../services/device_identity_service.dart';
import 'p2p_failures.dart';
import 'crypto_transport.dart';
import 'ble_native_transport.dart';

/// Helper for reading exact number of bytes from a Socket stream
class ChunkedDataReader {
  final StreamIterator<Uint8List> iterator;
  Uint8List _buffer = Uint8List(0);

  ChunkedDataReader(this.iterator);

  Future<Uint8List> readExact(int count) async {
    while (_buffer.length < count) {
      if (!await iterator.moveNext()) {
        throw Exception('Socket closed prematurely: expected $count bytes, got ${_buffer.length}');
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

/// Peer information container
class DiscoveredPeer {
  final String id;
  final String name;
  final Device? device;
  final String? ipAddress;
  final int? port;
  final String transportType;
  final String deviceType;

  DiscoveredPeer({
    required this.id,
    required this.name,
    this.device,
    this.ipAddress,
    this.port,
    this.transportType = 'wifi',
    this.deviceType = 'desktop',
  });
}

/// Abstract transport layer for offline Firewood P2P transfer
abstract class P2PTransport {
  Future<void> init();
  Future<void> startDiscovery({required Function(DiscoveredPeer peer) onPeerFound});
  Future<void> startAdvertising({required Function(DiscoveredPeer peer) onPeerConnected});
  Future<void> connect(DiscoveredPeer peer);
  Future<void> accept(DiscoveredPeer peer);
  Future<void> send(String peerId, Uint8List data);
  Future<String?> sendPayload(DiscoveredPeer peer, Uint8List data);
  Future<Uint8List> receiveEncryptedPayload(String peerId);
  Stream<Uint8List> receiveStream(String peerId);
  Future<void> disconnect();
  Future<void> dispose();
}

/// Production implementation utilizing flutter_nearby_connections_plus (BLE/Wi-Fi Direct)
/// Uses unified X25519 + HKDF-SHA256 + XChaCha20-Poly1305 encryption matching Tauri desktop
class NearbyTransport implements P2PTransport {
  NearbyService? _nearbyService;
  StreamSubscription? _stateSub;
  StreamSubscription? _dataSub;

  final StreamController<Map<String, Uint8List>> _incomingDataController =
      StreamController<Map<String, Uint8List>>.broadcast();

  final List<Device> _discoveredDevices = [];
  bool _isInit = false;

  // Per-peer crypto sessions for active transfers
  final Map<String, P2PCryptoSession> _cryptoSessions = {};

  /// Check if Bluetooth / NearbyConnections is available on this device.
  static Future<bool> isBluetoothAvailable() async {
    try {
      final svc = NearbyService();
      await svc.init(
        serviceType: 'firewood-p2p',
        strategy: Strategy.P2P_POINT_TO_POINT,
        callback: (_) {},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> init() async {
    if (_isInit) return;
    try {
      _nearbyService = NearbyService();
      await _nearbyService!.init(
        serviceType: 'firewood-p2p',
        strategy: Strategy.P2P_POINT_TO_POINT,
        callback: (data) {
          final peerId = data['deviceId'] as String? ?? 'unknown';
          final message = data['message'] as String? ?? '';
          try {
            final bytes = base64Decode(message);
            _incomingDataController.add({peerId: bytes});
          } catch (_) {
            final bytes = Uint8List.fromList(message.codeUnits);
            _incomingDataController.add({peerId: bytes});
          }
        },
      );
      _isInit = true;
    } catch (e) {
      throw TransportFailure('Failed to initialize Nearby transport', cause: e);
    }
  }

  @override
  Future<void> startDiscovery({required Function(DiscoveredPeer peer) onPeerFound}) async {
    await init();
    try {
      _stateSub?.cancel();
      _stateSub = _nearbyService!.stateChangedSubscription(
        callback: (devicesList) {
          for (final device in devicesList) {
            if (!_discoveredDevices.any((d) => d.deviceId == device.deviceId)) {
              _discoveredDevices.add(device);
              onPeerFound(
                DiscoveredPeer(
                  id: device.deviceId,
                  name: device.deviceName,
                  device: device,
                  transportType: 'bluetooth',
                  deviceType: 'phone',
                ),
              );
            }
          }
        },
      );
      await _nearbyService!.startBrowsingForPeers();
    } catch (e) {
      throw TransportFailure('Failed to start BLE/Wi-Fi peer discovery', cause: e);
    }
  }

  @override
  Future<void> startAdvertising({required Function(DiscoveredPeer peer) onPeerConnected}) async {
    await init();
    try {
      _stateSub?.cancel();
      _stateSub = _nearbyService!.stateChangedSubscription(
        callback: (devicesList) {
          for (final device in devicesList) {
            if (device.state == SessionState.connected) {
              onPeerConnected(
                DiscoveredPeer(
                  id: device.deviceId,
                  name: device.deviceName,
                  device: device,
                  transportType: 'bluetooth',
                  deviceType: 'phone',
                ),
              );
            }
          }
        },
      );
      await _nearbyService!.startAdvertisingPeer();
    } catch (e) {
      throw TransportFailure('Failed to start peer advertising', cause: e);
    }
  }

  @override
  Future<void> connect(DiscoveredPeer peer) async {
    try {
      await _nearbyService!.invitePeer(
        deviceID: peer.id,
        deviceName: peer.name,
      );
    } catch (e) {
      throw TransportFailure('Failed to connect to peer ${peer.name}', cause: e);
    }
  }

  @override
  Future<void> accept(DiscoveredPeer peer) async {}

  @override
  Future<void> send(String peerId, Uint8List data) async {
    try {
      final strMsg = base64Encode(data);
      await _nearbyService!.sendMessage(peerId, strMsg);
    } catch (e) {
      throw TransportFailure('Failed to send packet to $peerId', cause: e);
    }
  }

  /// Send encrypted payload with full X25519 handshake
  /// Returns SAS code for user verification
  @override
  Future<String?> sendPayload(DiscoveredPeer peer, Uint8List data) async {
    await connect(peer);
    
    final session = P2PCryptoSession();
    _cryptoSessions[peer.id] = session;
    
    try {
      // 1. Generate our ephemeral keypair
      final ourPubKey = await session.initializeAsInitiator();
      
      // 2. Send raw 32-byte public key (FIX: was base64-encoded then .codeUnits – corrupted)
      await send(peer.id, ourPubKey);
      
      // 3. Receive peer's public key with timeout
      final peerPubKey = await _receiveExactBytes(peer.id, X25519_KEY_SIZE);
      session.setPeerPublicKey(peerPubKey);
      
      // 4. Complete handshake (derive session key + SAS)
      await session.completeHandshake();
      
      // 5. Encrypt payload
      final encryptedPacket = await session.encrypt(data);
      
      // 6. Send encrypted packet
      await send(peer.id, encryptedPacket);
      
      return session.sasCode; // FIX: re-enable SAS for user verification
    } catch (e) {
      _cryptoSessions.remove(peer.id);
      rethrow;
    }
  }

  /// Receive and decrypt payload (responder side)
  /// Used by the receiving device
  @override
  Future<Uint8List> receiveEncryptedPayload(String peerId) async {
    // Check if we have an existing session for this peer
    P2PCryptoSession? session = _cryptoSessions[peerId];
    
    if (session == null) {
      // We're the responder - need to do handshake
      session = P2PCryptoSession();
      _cryptoSessions[peerId] = session;
      
      // 1. Receive peer's public key
      final peerPubKey = await _receiveExactBytes(peerId, X25519_KEY_SIZE);
      
      // 2. Generate our keypair and send our public key (raw 32 bytes)
      final ourPubKey = await session.initializeAsResponder(peerPubKey);
      await send(peerId, ourPubKey);
      
      // 3. Complete handshake
      await session.completeHandshake();
    }
    
    // 4. Receive encrypted packet
    final encryptedPacket = await _receiveEncryptedPacket(peerId);
    
    // 5. Decrypt
    final decrypted = await session.decrypt(encryptedPacket);
    
    _cryptoSessions.remove(peerId);
    return decrypted;
  }

  /// Helper: receive exactly N bytes from peer
  /// The callback already base64-decodes incoming messages, so data arrives as raw bytes.
  Future<Uint8List> _receiveExactBytes(String peerId, int expectedBytes) async {
    final stream = receiveStream(peerId);
    final completer = Completer<Uint8List>();
    Uint8List buffer = Uint8List(0);
    
    late StreamSubscription subscription;
    subscription = stream.listen((data) async {
      buffer = Uint8List.fromList([...buffer, ...data]);
      
      if (buffer.length >= expectedBytes) {
        final result = buffer.sublist(0, expectedBytes);
        buffer = buffer.sublist(expectedBytes);
        await subscription.cancel();
        completer.complete(result);
      }
    });
    
    return completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
      throw TimeoutFailure('Timed out waiting for handshake data');
    });
  }

  /// Helper: receive full encrypted packet (with length prefix)
  Future<Uint8List> _receiveEncryptedPacket(String peerId) async {
    final stream = receiveStream(peerId);
    final completer = Completer<Uint8List>();
    Uint8List buffer = Uint8List(0);
    
    late StreamSubscription subscription;
    subscription = stream.listen((data) async {
      buffer = Uint8List.fromList([...buffer, ...data]);
      
      // Check if we have at least the length prefix
      if (buffer.length >= LENGTH_PREFIX_SIZE) {
        final lenBytes = buffer.sublist(0, LENGTH_PREFIX_SIZE);
        final bd = ByteData.sublistView(lenBytes);
        final packetLen = bd.getUint32(0, Endian.big);
        final totalExpected = LENGTH_PREFIX_SIZE + packetLen;
        
        if (buffer.length >= totalExpected) {
          final result = buffer.sublist(0, totalExpected);
          buffer = buffer.sublist(totalExpected);
          await subscription.cancel();
          completer.complete(result);
        }
      }
    });
    
    return completer.future.timeout(const Duration(seconds: 45), onTimeout: () {
      throw TimeoutFailure('Timed out waiting for encrypted payload');
    });
  }

  @override
  Stream<Uint8List> receiveStream(String peerId) {
    return _incomingDataController.stream
        .where((map) => map.containsKey(peerId))
        .map((map) => map[peerId]!);
  }

  @override
  Future<void> disconnect() async {
    try {
      await _nearbyService!.stopAdvertisingPeer();
      await _nearbyService!.stopBrowsingForPeers();
    } catch (_) {}
    // Dispose all crypto sessions
    for (final session in _cryptoSessions.values) {
      session.dispose();
    }
    _cryptoSessions.clear();
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _stateSub?.cancel();
    await _dataSub?.cancel();
    await _incomingDataController.close();
  }
}

/// UDP/TCP Socket implementation for Desktop (Tauri) <-> Android cross-platform P2P
class LanSocketTransport implements P2PTransport {
  static const int discoveryPort = 52719;
  static const int tcpPort = 52720;

  RawDatagramSocket? _udpSocket;
  Timer? _beaconTimer;
  ServerSocket? _tcpServer;

  final Map<String, Socket> _activeConnections = {};
  final StreamController<Map<String, Uint8List>> _incomingDataController =
      StreamController<Map<String, Uint8List>>.broadcast();

  bool _isInit = false;

  /// Check if a usable LAN is available by probing network interfaces.
  static Future<bool> isLanAvailable() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      return interfaces.any(
        (iface) => iface.addresses.any((a) => !a.isLoopback),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> init() async {
    if (_isInit) return;
    _isInit = true;
  }

  @override
  Future<void> startDiscovery({required Function(DiscoveredPeer peer) onPeerFound}) async {
    await init();
    try {
      final ourDeviceId = await DeviceIdentityService.getDeviceId();
      _udpSocket?.close();
      try {
        _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort, reuseAddress: true);
      } catch (_) {
        _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: true);
      }
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket!.receive();
          if (dg != null) {
            try {
              final str = utf8.decode(dg.data);
              final json = jsonDecode(str) as Map<String, dynamic>;
              if (json['magic'] == 'FIREWOOD_P2P_BEACON_V1') {
                final id = json['id'] as String;

                // Skip self-discovery from our own device ID
                if (id == ourDeviceId) return;
                final name = json['name'] as String;
                final port = (json['tcpPort'] as num?)?.toInt() ?? tcpPort;
                final transportType = json['transport'] as String? ?? 'wifi';
                final deviceType = json['deviceType'] as String? ?? 'desktop';

                onPeerFound(
                  DiscoveredPeer(
                    id: id,
                    name: name,
                    ipAddress: dg.address.address,
                    port: port,
                    transportType: transportType,
                    deviceType: deviceType,
                  ),
                );
              }
            } catch (_) {}
          }
        }
      });

      // Broadcast discovery beacons every 2 seconds using persistent DeviceIdentityService
      final deviceId = await DeviceIdentityService.getDeviceId();
      final deviceAlias = await DeviceIdentityService.getDeviceAlias();

      final beaconJson = jsonEncode({
        'magic': 'FIREWOOD_P2P_BEACON_V1',
        'id': deviceId,
        'name': deviceAlias,
        'tcpPort': tcpPort,
        'transport': 'wifi',
        'deviceType': 'phone',
      });

      _beaconTimer?.cancel();
      _beaconTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          final bytes = utf8.encode(beaconJson);
          _udpSocket?.send(bytes, InternetAddress('255.255.255.255'), discoveryPort);
          final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
          for (final iface in interfaces) {
            for (final addr in iface.addresses) {
              if (!addr.isLoopback) {
                final parts = addr.address.split('.');
                if (parts.length == 4) {
                  final bcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
                  try {
                    _udpSocket?.send(bytes, InternetAddress(bcast), discoveryPort);
                  } catch (_) {}
                }
              }
            }
          }
        } catch (_) {}
      });
    } catch (e) {
      throw TransportFailure('Failed to start UDP discovery listener: $e', cause: e);
    }
  }

  @override
  Future<void> startAdvertising({required Function(DiscoveredPeer peer) onPeerConnected}) async {
    await startDiscovery(onPeerFound: (_) {});
    try {
      _tcpServer?.close();
      _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort, shared: true);
      _tcpServer!.listen((Socket socket) async {
        final peerId = 'peer-${socket.remoteAddress.address}';

        onPeerConnected(
          DiscoveredPeer(
            id: peerId,
            name: 'Desktop Peer (${socket.remoteAddress.address})',
            ipAddress: socket.remoteAddress.address,
            port: socket.remotePort,
            transportType: 'wifi',
            deviceType: 'desktop',
          ),
        );

        try {
          final reader = ChunkedDataReader(StreamIterator(socket));
          final session = P2PCryptoSession();

          // 1. Read peer's 32-byte public key
          final peerPubBytes = await reader.readExact(X25519_KEY_SIZE);
          
          // 2. Initialize as responder (generates our keypair, sends our pubkey)
          final ourPubBytes = await session.initializeAsResponder(peerPubBytes);
          socket.add(ourPubBytes);
          await socket.flush();

          // 3. Complete handshake (derive session key + SAS via Sha256)
          await session.completeHandshake();

          // 4. Read encrypted wire packet (length + nonce + ciphertext)
          final encryptedPacket = await _readWirePacket(reader);
          
          // 5. Decrypt using unified crypto
          final decryptedBytes = await session.decrypt(encryptedPacket);

          _incomingDataController.add({peerId: decryptedBytes});
        } catch (e) {
          stderr.writeln('LanSocketTransport receive error: $e');
        } finally {
          socket.destroy();
        }
      });
    } catch (e) {
      throw TransportFailure('Failed to start TCP receiver server: $e', cause: e);
    }
  }

  /// Read wire packet: [4-byte length][nonce + ciphertext]
  Future<Uint8List> _readWirePacket(ChunkedDataReader reader) async {
    final lenBytes = await reader.readExact(LENGTH_PREFIX_SIZE);
    final bd = ByteData.sublistView(lenBytes);
    final packetLen = bd.getUint32(0, Endian.big);

    if (packetLen < XCHACHA_NONCE_SIZE || packetLen > MAX_PAYLOAD_SIZE) {
      throw Exception('Invalid payload size: $packetLen');
    }

    return await reader.readExact(packetLen);
  }

  @override
  Future<void> connect(DiscoveredPeer peer) async {}

  @override
  Future<void> accept(DiscoveredPeer peer) async {}

  /// Send payload over TCP to a LAN peer using unified X25519 + HKDF + XChaCha20-Poly1305
  /// Matches Tauri desktop implementation exactly
  Future<String?> sendLanPayload(DiscoveredPeer peer, Uint8List payloadData) async {
    final ipAddress = peer.ipAddress;
    final port = peer.port ?? tcpPort;
    if (ipAddress == null) {
      throw const TransportFailure('Missing IP address for peer socket connection');
    }

    final socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 10));
    try {
      final reader = ChunkedDataReader(StreamIterator(socket));
      final session = P2PCryptoSession();

      // 1. Initialize as initiator (generate keypair)
      final ourPubBytes = await session.initializeAsInitiator();

      // 2. Transmit our 32-byte public key
      socket.add(ourPubBytes);
      await socket.flush();

      // 3. Read peer's 32-byte public key
      final peerPubBytes = await reader.readExact(X25519_KEY_SIZE);
      session.setPeerPublicKey(peerPubBytes);

      // 4. Complete handshake (derive session key via HKDF)
      await session.completeHandshake();

      // 5. Encrypt payload (no SAS embedding)
      final encryptedPacket = await session.encrypt(payloadData);

      // 6. Send encrypted wire packet
      socket.add(encryptedPacket);
      await socket.flush();

      return session.sasCode; // FIX: re-enable SAS for user verification
    } catch (e) {
      throw TransportFailure('Failed to send payload over LAN to ${peer.name}: $e', cause: e);
    } finally {
      socket.destroy();
    }
  }

  @override
  Future<void> send(String peerId, Uint8List data) async {}

  @override
  Future<String?> sendPayload(DiscoveredPeer peer, Uint8List data) async {
    return await sendLanPayload(peer, data);
  }

  @override
  Stream<Uint8List> receiveStream(String peerId) {
    return _incomingDataController.stream
        .where((map) => map.containsKey(peerId))
        .map((map) => map[peerId]!);
  }

  @override
  Future<Uint8List> receiveEncryptedPayload(String peerId) async {
    throw UnimplementedError('LanSocketTransport.receiveEncryptedPayload not used');
  }

  @override
  Future<void> disconnect() async {
    _beaconTimer?.cancel();
    _udpSocket?.close();
    await _tcpServer?.close();
    for (final s in _activeConnections.values) {
      s.destroy();
    }
    _activeConnections.clear();
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _incomingDataController.close();
  }
}

/// Firewood P2P Node Roles
enum P2PRole { listener, client }

/// TransportManager dynamically switches between multiple transports
class TransportManager implements P2PTransport {
  static const int maxNodes = 2;
  static const int minPayloadBytes = 1024;        // 1 KB
  static const int maxPayloadBytes = 500 * 1024 * 1024;   // 500 MB

  final List<P2PTransport> _transports = [
    NearbyTransport(),
    LanSocketTransport(),
    BleNativeTransport(), // Native Kotlin BLE (replaces flutter_nearby_connections_plus)
  ];

  bool _transportActive = false;
  P2PRole _currentRole = P2PRole.listener;
  int _connectedNodeCount = 0;

  final StreamController<String> _transportTypeController =
      StreamController<String>.broadcast();

  String get activeTransportType => 'nearby';
  P2PRole get currentRole => _currentRole;
  int get connectedNodeCount => _connectedNodeCount;

  Stream<String> get transportTypeStream => _transportTypeController.stream;

  /// Switch role between Listener (Advertising) and Client (Scanning)
  Future<void> switchRole(P2PRole newRole) async {
    _currentRole = newRole;
    await disconnect();
  }

  @override
  Future<void> init() async {
    for (final transport in [_transports[0], _transports[1], _transports[2]]) {
      try {
        await transport.init();
      } catch (_) {}
    }
    _transportActive = true;
    _transportTypeController.add(activeTransportType);
  }

  @override
  Future<void> startDiscovery({required Function(DiscoveredPeer peer) onPeerFound}) async {
    await init();
    _currentRole = P2PRole.client;
    if (_transportActive) {
      for (final transport in [_transports[0], _transports[1], _transports[2]]) {
        try {
          await transport.startDiscovery(
            onPeerFound: (peer) {
              if (_connectedNodeCount < maxNodes) {
                onPeerFound(peer);
              }
            },
          );
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> startAdvertising({required Function(DiscoveredPeer peer) onPeerConnected}) async {
    await init();
    _currentRole = P2PRole.listener;
    if (_transportActive) {
      for (final transport in [_transports[0], _transports[1], _transports[2]]) {
        try {
          await transport.startAdvertising(
            onPeerConnected: (peer) {
              if (_connectedNodeCount < maxNodes) {
                _connectedNodeCount++;
                onPeerConnected(peer);
              }
            },
          );
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> connect(DiscoveredPeer peer) async {
    if (_connectedNodeCount >= maxNodes) {
      throw const TransportFailure('Maximum 2 nodes allowed in P2P session');
    }
    if (_transportActive) {
      P2PTransport targetTransport = _transports[0];
      if (peer.ipAddress != null || peer.transportType == 'wifi') {
        targetTransport = _transports[1];
      } else if (peer.transportType == 'ble_native') {
        targetTransport = _transports[2];
      }

      int attempts = 0;
      Object? lastError;
      while (attempts < 3) {
        try {
          attempts++;
          await targetTransport.connect(peer);
          _connectedNodeCount++;
          return;
        } catch (e) {
          lastError = e;
          await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }
      throw TransportFailure('Transport connection failed after 3 attempts: ${lastError?.toString()}');
    }
  }

  @override
  Future<void> accept(DiscoveredPeer peer) async {
    if (_transportActive) {
      for (final t in [_transports[0], _transports[1], _transports[2]]) {
        try {
          await t.accept(peer);
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> send(String peerId, Uint8List data) async {
    if (data.length > maxPayloadBytes) {
      throw TransportFailure('Payload size (${data.length} bytes) exceeds 500 MB maximum limit');
    }
    if (_transportActive) {
      for (final t in [_transports[0], _transports[1], _transports[2]]) {
        try {
          await t.send(peerId, data);
        } catch (_) {}
      }
    }
  }

  @override
  Future<String?> sendPayload(DiscoveredPeer peer, Uint8List data) async {
    if (data.length > maxPayloadBytes) {
      throw TransportFailure('Payload size (${data.length} bytes) exceeds 500 MB maximum limit');
    }
    if (_transportActive) {
      P2PTransport targetTransport = _transports[0];
      if (peer.ipAddress != null || peer.transportType == 'wifi') {
        targetTransport = _transports[1];
      } else if (peer.transportType == 'ble_native') {
        targetTransport = _transports[2];
      }
      return await targetTransport.sendPayload(peer, data);
    }
    throw const TransportFailure('No active transport available for payload transfer');
  }

  @override
  Stream<Uint8List> receiveStream(String peerId) {
    if (_transportActive) {
      final controller = StreamController<Uint8List>.broadcast();
      final sub1 = _transports[0].receiveStream(peerId).listen(controller.add);
      final sub2 = _transports[1].receiveStream(peerId).listen(controller.add);
      final sub3 = _transports[2].receiveStream(peerId).listen(controller.add);
      controller.onCancel = () {
        sub1.cancel();
        sub2.cancel();
        sub3.cancel();
      };
      return controller.stream;
    }
    return const Stream.empty();
  }

  @override
  Future<Uint8List> receiveEncryptedPayload(String peerId) async {
    if (_transportActive) {
      // Try BleNativeTransport first (full handshake + decrypt)
      try {
        return await _transports[2].receiveEncryptedPayload(peerId);
      } catch (_) {}

      // Fall back to NearbyTransport
      return await _transports[0].receiveEncryptedPayload(peerId);
    }
    throw const TransportFailure('No active transport available');
  }

  @override
  Future<void> disconnect() async {
    if (_transportActive) {
      for (final t in [_transports[0], _transports[1], _transports[2]]) {
        try {
          await t.disconnect();
        } catch (_) {}
      }
    }
    _connectedNodeCount = 0;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    for (final t in [_transports[0], _transports[1], _transports[2]]) {
      try {
        await t.dispose();
      } catch (_) {}
    }
    await _transportTypeController.close();
  }
}
