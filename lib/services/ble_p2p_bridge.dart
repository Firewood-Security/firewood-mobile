// services/ble_p2p_bridge.dart
// Flutter ↔ Native BLE P2P bridge via EventChannel + MethodChannel.
//
// Complements NearbyTransport with a native Android BLE implementation
// that does NOT rely on flutter_nearby_connections_plus.
//
// Architecture:
//  - MethodChannel "com.firewood.vault_security" for BLE commands
//  - EventChannel "com.firewood.ble/discovery" for device scan results
//  - EventChannel "com.firewood.ble/connection" for GATT connect/disconnect
//  - EventChannel "com.firewood.ble/data" for incoming characteristic data
//
// The crypto handshake (X25519 + XChaCha20-Poly1305) stays in Dart
// via P2PCryptoSession. BLE is just the transport pipe for raw bytes.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class BleP2PBridge {
  static const _methodChannel = MethodChannel('com.firewood.vault_security');

  // Event streams
  static final _discoveryStream = EventChannel('com.firewood.ble/discovery')
      .receiveBroadcastStream();
  static final _connectionStream = EventChannel('com.firewood.ble/connection')
      .receiveBroadcastStream();
  static final _dataStream = EventChannel('com.firewood.ble/data')
      .receiveBroadcastStream();

  static bool _initialized = false;

  /// Ensures the native BLE manager is ready (no-op, init happens lazily).
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
  }

  // --- Advertiser (Receiver role) ---

  static Future<bool> startAdvertise() async {
    final result = await _methodChannel.invokeMethod<bool>('bleStartAdvertise');
    return result ?? false;
  }

  static Future<bool> stopAdvertise() async {
    final result = await _methodChannel.invokeMethod<bool>('bleStopAdvertise');
    return result ?? false;
  }

  // --- Scanner (Sender role) ---

  static Future<bool> startScan() async {
    final result = await _methodChannel.invokeMethod<bool>('bleStartScan');
    return result ?? false;
  }

  static Future<bool> stopScan() async {
    final result = await _methodChannel.invokeMethod<bool>('bleStopScan');
    return result ?? false;
  }

  // --- Connection (Sender connects to discovered device) ---

  static Future<bool> connectDevice(String deviceAddress) async {
    final result = await _methodChannel.invokeMethod<bool>('bleConnectDevice', {
      'deviceAddress': deviceAddress,
    });
    return result ?? false;
  }

  // --- Data Transfer ---

  /// Sends raw bytes over BLE GATT to the connected device.
  /// For large payloads (> MTU), the caller should chunk the data.
  static Future<bool> sendData(String deviceAddress, Uint8List data) async {
    final result = await _methodChannel.invokeMethod<bool>('bleSendData', {
      'deviceAddress': deviceAddress,
      'data': data,
    });
    return result ?? false;
  }

  static Future<bool> disconnectDevice(String deviceAddress) async {
    final result = await _methodChannel.invokeMethod<bool>('bleDisconnectDevice', {
      'deviceAddress': deviceAddress,
    });
    return result ?? false;
  }

  static Future<bool> shutdown() async {
    final result = await _methodChannel.invokeMethod<bool>('bleShutdown');
    return result ?? false;
  }

  // --- Event Streams ---

  /// Stream of discovered BLE devices: {event, deviceId, deviceName, rssi}
  static Stream<Map<String, dynamic>> get discoveryStream =>
      _discoveryStream.cast<Map<dynamic, dynamic>>().map((e) => Map<String, dynamic>.from(e));

  /// Stream of connection state changes: {event, deviceId, deviceName?, role}
  static Stream<Map<String, dynamic>> get connectionStream =>
      _connectionStream.cast<Map<dynamic, dynamic>>().map((e) => Map<String, dynamic>.from(e));

  /// Stream of incoming data: {deviceId, data: Uint8List}
  static Stream<Map<String, dynamic>> get dataStream =>
      _dataStream.cast<Map<dynamic, dynamic>>().map((e) => Map<String, dynamic>.from(e));
}
