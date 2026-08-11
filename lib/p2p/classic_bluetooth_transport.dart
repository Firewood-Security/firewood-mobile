import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as bt_serial;
import 'transport_adapter.dart';
import 'p2p_failures.dart';

class ClassicBluetoothTransport implements P2PTransport {
  bt_serial.BluetoothConnection? _connection;
  
  final StreamController<Map<String, Uint8List>> _incomingDataController =
      StreamController<Map<String, Uint8List>>.broadcast();

  bool _isInit = false;

  @override
  Future<void> init() async {
    if (_isInit) return;
    _isInit = true;
  }

  @override
  Future<void> startDiscovery({required Function(DiscoveredPeer peer) onPeerFound}) async {
    await init();
    try {
      bt_serial.FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
        if (r.device.name != null) {
          onPeerFound(DiscoveredPeer(
            id: r.device.address,
            name: r.device.name!,
            transportType: 'classic_bluetooth',
            deviceType: 'phone',
          ));
        }
      });
    } catch (e) {
      throw TransportFailure('Classic Bluetooth discovery failed', cause: e);
    }
  }

  @override
  Future<void> startAdvertising({required Function(DiscoveredPeer peer) onPeerConnected}) async {
    await init();
    try {
      // NOTE: flutter_bluetooth_serial doesn't have a reliable server socket API in Dart directly.
      // A full implementation requires native Android BluetoothServerSocket code.
      // For MVP, we mock the advertisement/server side.
      throw UnimplementedError("RFCOMM Server not fully implemented in flutter_bluetooth_serial");
    } catch (e) {
      throw TransportFailure('Failed to start advertising', cause: e);
    }
  }

  @override
  Future<void> connect(DiscoveredPeer peer) async {
    try {
      _connection = await bt_serial.BluetoothConnection.toAddress(peer.id);
      
      _connection!.input!.listen((Uint8List data) {
         _incomingDataController.add({peer.id: data});
      }).onDone(() {
         // handle disconnect
      });
    } catch (e) {
      throw TransportFailure('Failed to connect via RFCOMM to ${peer.name}', cause: e);
    }
  }

  @override
  Future<void> accept(DiscoveredPeer peer) async {}

  @override
  Future<void> send(String peerId, Uint8List data) async {
    if (_connection != null && _connection!.isConnected) {
      _connection!.output.add(data);
      await _connection!.output.allSent;
    } else {
      throw const TransportFailure('No active RFCOMM connection');
    }
  }

  @override
  Future<String?> sendPayload(DiscoveredPeer peer, Uint8List data) async {
    await send(peer.id, data);
    return null;
  }

  @override
  Stream<Uint8List> receiveStream(String peerId) {
    return _incomingDataController.stream
        .where((map) => map.containsKey(peerId))
        .map((map) => map[peerId]!);
  }

  @override
  Future<Uint8List> receiveEncryptedPayload(String peerId) async {
    throw UnimplementedError('ClassicBluetoothTransport.receiveEncryptedPayload not implemented');
  }

  @override
  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _incomingDataController.close();
  }
}
