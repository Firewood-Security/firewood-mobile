// p2p/session_manager.dart
// Session lifecycle & state orchestration for Firewood P2P system

import 'dart:async';
import 'dart:typed_data';
import 'p2p_failures.dart';
import 'transfer_models.dart';
import 'transport_adapter.dart';

/// Manages P2P session lifecycle, timeouts, state transitions, and automatic cleanup.
class SessionManager {
  final P2PTransport _transport;

  TransferState _state = TransferState.idle;
  DiscoveredPeer? _connectedPeer;
  String? _errorMessage;

  final StreamController<TransferState> _stateController =
      StreamController<TransferState>.broadcast();
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  SessionManager({P2PTransport? transport})
      : _transport = transport ?? TransportManager();

  TransferState get state => _state;
  DiscoveredPeer? get connectedPeer => _connectedPeer;
  String? get errorMessage => _errorMessage;

  Stream<TransferState> get stateStream => _stateController.stream;
  Stream<double> get progressStream => _progressController.stream;

  void _updateState(TransferState newState, {String? error}) {
    _state = newState;
    _errorMessage = error;
    _stateController.add(newState);
  }

  /// Start discovering nearby peers (Sender flow)
  Future<void> startDiscovery({required Function(DiscoveredPeer peer) onPeerFound}) async {
    _updateState(TransferState.discovering);
    try {
      await _transport.startDiscovery(onPeerFound: onPeerFound);
    } catch (e) {
      _updateState(TransferState.failed, error: e.toString());
      rethrow;
    }
  }

  /// Start advertising for incoming connection requests (Receiver flow)
  Future<void> startAdvertising({required Function(DiscoveredPeer peer) onPeerConnected}) async {
    _updateState(TransferState.discovering);
    try {
      await _transport.startAdvertising(
        onPeerConnected: (peer) {
          _connectedPeer = peer;
          _updateState(TransferState.connecting);
          onPeerConnected(peer);
        },
      );
    } catch (e) {
      _updateState(TransferState.failed, error: e.toString());
      rethrow;
    }
  }

  /// Initiate connection to a discovered peer
  Future<void> connect(DiscoveredPeer peer) async {
    _connectedPeer = peer;
    _updateState(TransferState.connecting);
    try {
      await _transport.connect(peer);
    } catch (e) {
      _updateState(TransferState.failed, error: e.toString());
      rethrow;
    }
  }

  /// Send payload directly to a peer (initiator/sender).
  /// Returns the SAS verification code for mutual confirmation.
  Future<String> sendPayloadToPeer(DiscoveredPeer peer, Uint8List payload) async {
    _connectedPeer = peer;
    String? sasCode;
    try {
      _updateState(TransferState.encrypting);
      _progressController.add(0.3);

      sasCode = await _transport.sendPayload(peer, payload);

      _progressController.add(1.0);
      _updateState(TransferState.completed);
    } catch (e) {
      _updateState(TransferState.failed, error: e.toString());
      rethrow;
    } finally {
      _cleanupSession();
    }
    return sasCode ?? '00000';
  }

  /// Receive and decrypt payload (responder/receiver)
  /// Works for LAN, Nearby, and BLE transports
  Future<Uint8List> receiveEncryptedPayload(DiscoveredPeer peer) async {
    _connectedPeer = peer;
    _updateState(TransferState.receiving);
    _progressController.add(0.5);

    try {
      final bool isNearbyOrBle =
          _transport is NearbyTransport || peer.transportType == 'ble_native';

      if (isNearbyOrBle) {
        // NearbyTransport and BleNativeTransport both have receiveEncryptedPayload
        // that handles handshake + decryption internally.
        final decrypted = await _transport.receiveEncryptedPayload(peer.id);
        _progressController.add(1.0);
        _updateState(TransferState.completed);
        return decrypted;
      }

      // LAN transport: payload arrives already decrypted in one piece
      final raw = await _transport
          .receiveStream(peer.id)
          .first
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () =>
                throw const TimeoutFailure('Timed out waiting for transfer payload'),
          );

      _progressController.add(1.0);
      _updateState(TransferState.completed);
      return raw;
    } catch (e) {
      _updateState(TransferState.failed, error: e.toString());
      rethrow;
    } finally {
      _cleanupSession();
    }
  }

  /// Cancel transfer and reset state
  Future<void> cancel() async {
    _updateState(TransferState.idle);
    await _cleanupSession();
  }

  /// Destroy temporary cryptographic keys and disconnect transport
  Future<void> _cleanupSession() async {
    await _transport.disconnect();
    _connectedPeer = null;
  }

  Future<void> dispose() async {
    await _cleanupSession();
    await _transport.dispose();
    await _stateController.close();
    await _progressController.close();
  }
}
