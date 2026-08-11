import 'dart:async';
import 'dart:typed_data';
import '../transport_adapter.dart';

class UsbTransport implements P2PTransport {
  @override
  Future<void> init() async {}

  @override
  Future<void> startDiscovery({required Function(DiscoveredPeer peer) onPeerFound}) async {}

  @override
  Future<void> startAdvertising({required Function(DiscoveredPeer peer) onPeerConnected}) async {}

  @override
  Future<void> connect(DiscoveredPeer peer) async {}

  @override
  Future<void> accept(DiscoveredPeer peer) async {}

  @override
  Future<void> send(String peerId, Uint8List data) async {}

  @override
  Future<String?> sendPayload(DiscoveredPeer peer, Uint8List data) async {
    return null;
  }

  @override
  Stream<Uint8List> receiveStream(String peerId) {
    return const Stream.empty();
  }

  @override
  Future<Uint8List> receiveEncryptedPayload(String peerId) async {
    throw UnimplementedError('UsbTransport.receiveEncryptedPayload not implemented');
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}
}
