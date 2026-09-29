// BLE P2P service bridging to the native Android BleP2PManager.
//
// Supports both roles:
//   - Sender: scan → pick peer → connect → send encrypted .firewood payload
//   - Receiver: advertise → wait → receive encrypted payload
//
// Uses the same framed protocol as the desktop transport (4-byte payload length +
// 2-byte name length + filename + payload) over a shared GATT characteristic.
// Chunking, write flow control and reassembly happen natively (see BleP2PManager):
// sendData() queues the whole frame, and the data channel reports progress and
// completion; incoming data arrives as one event per complete frame.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_frame.dart';

/// Which BLE role we are about to take, used to request the right runtime
/// permissions on Android 12+.
enum BleRole { sender, receiver }

class BleP2pService {
  static const _method = MethodChannel('com.firewood.vault_security');
  static const _discoveryChannel = EventChannel('com.firewood.ble/discovery');
  static const _connectionChannel = EventChannel('com.firewood.ble/connection');
  static const _dataChannel = EventChannel('com.firewood.ble/data');

  StreamSubscription? _discoverySub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _dataSub;

  final _discoveredDevicesController = StreamController<BleDevice>.broadcast();
  final _connectionController =
      StreamController<BleConnectionEvent>.broadcast();
  final _transferController = StreamController<BleTransferEvent>.broadcast();

  /// Stream of discovered Firewood peers during scanning.
  Stream<BleDevice> get onDeviceFound => _discoveredDevicesController.stream;

  /// Stream of connection events (connected / disconnected / failed).
  Stream<BleConnectionEvent> get onConnectionEvent =>
      _connectionController.stream;

  /// Stream of transfer events (progress / complete / failed / received).
  Stream<BleTransferEvent> get onTransferEvent => _transferController.stream;

  bool _disposed = false;

  BleP2pService() {
    _listenStreams();
  }

  // ---------- Permissions & state ----------

  /// Requests the Android 12+ runtime permissions required for [role].
  /// Returns false when the user declined (or permanently denied).
  Future<bool> ensurePermissions(BleRole role) async {
    final needed = <Permission>[
      if (role == BleRole.sender) ...[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ] else ...[
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ],
    ];

    var granted = true;
    var permanentlyDenied = false;
    for (final permission in needed) {
      var status = await permission.status;
      if (!status.isGranted) status = await permission.request();
      if (!status.isGranted) {
        granted = false;
        if (status.isPermanentlyDenied) permanentlyDenied = true;
      }
    }

    if (permanentlyDenied && !_disposed) {
      await openAppSettings();
    }
    return granted;
  }

  Future<bool> isBluetoothEnabled() async {
    try {
      return await _method.invokeMethod<bool>('checkBluetoothEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  void _listenStreams() {
    _discoverySub?.cancel();
    _discoverySub = _discoveryChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event as Map);
      _discoveredDevicesController.add(BleDevice(
        address: map['deviceId']?.toString() ?? '',
        name: map['deviceName']?.toString() ?? 'Unknown',
        rssi: map['rssi'] as int? ?? 0,
      ));
    }, onError: (_) {});

    _connectionSub?.cancel();
    _connectionSub =
        _connectionChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event as Map);
      final kind = map['event']?.toString() ?? '';
      _connectionController.add(BleConnectionEvent(
        address: map['deviceId']?.toString() ?? '',
        connected: kind == 'connected',
        role: map['role']?.toString(),
        error: map['error']?.toString(),
      ));
    }, onError: (Object error) {
      _connectionController.add(BleConnectionEvent(
        address: '',
        connected: false,
        error: error.toString(),
      ));
    });

    _dataSub?.cancel();
    _dataSub = _dataChannel.receiveBroadcastStream().listen((event) {
      final map = Map<String, dynamic>.from(event as Map);
      final kind = map['event']?.toString();

      if (kind == 'send_progress') {
        _transferController.add(BleTransferEvent(
          kind: BleTransferEventKind.progress,
          sent: map['sent'] as int? ?? 0,
          total: map['total'] as int? ?? 0,
        ));
      } else if (kind == 'send_complete') {
        _transferController.add(BleTransferEvent(
          kind: BleTransferEventKind.sendComplete,
          total: map['total'] as int? ?? 0,
        ));
      } else if (kind == 'send_failed') {
        _transferController.add(BleTransferEvent(
          kind: BleTransferEventKind.sendFailed,
          error: map['error']?.toString() ?? 'Transfer failed',
        ));
      } else {
        // No event key → a complete incoming frame reassembled by the native layer.
        final payload = map['data'];
        if (payload is Uint8List) {
          _transferController.add(BleTransferEvent(
            kind: BleTransferEventKind.received,
            frame: payload,
            address: map['deviceId']?.toString() ?? '',
          ));
        }
      }
    }, onError: (Object error) {
      _transferController.add(BleTransferEvent(
        kind: BleTransferEventKind.sendFailed,
        error: error.toString(),
      ));
    });
  }

  // ---------- Receiver (advertiser) role ----------

  /// Starts BLE advertising the Firewood service so senders can discover us.
  Future<bool> startAdvertising() async {
    return await _method.invokeMethod<bool>('bleStartAdvertise') ?? false;
  }

  Future<void> stopAdvertising() async {
    await _method.invokeMethod('bleStopAdvertise');
  }

  // ---------- Sender (scanner) role ----------

  /// Scans for nearby Firewood peers.
  Future<bool> startScanning() async {
    return await _method.invokeMethod<bool>('bleStartScan') ?? false;
  }

  Future<void> stopScanning() async {
    await _method.invokeMethod('bleStopScan');
  }

  /// Connects to a discovered peer and waits until the GATT service is ready.
  Future<void> connect(String address,
      {Duration timeout = const Duration(seconds: 20)}) async {
    final connected = onConnectionEvent
        .where((e) => e.address == address && e.connected)
        .first
        .timeout(timeout,
            onTimeout: () => throw BleException(
                  'Timed out connecting to $address',
                ));

    final started = await _method.invokeMethod<bool>(
          'bleConnectDevice',
          <String, dynamic>{'deviceAddress': address},
        ) ??
        false;
    if (!started) {
      throw BleException('Could not start BLE connection to $address');
    }
    await connected;
  }

  Future<void> disconnect(String address) async {
    await _method.invokeMethod(
      'bleDisconnectDevice',
      <String, dynamic>{'deviceAddress': address},
    );
  }

  /// Sends a framed file payload over BLE and completes when the native layer has
  /// written every chunk. [onProgress] reports bytes sent / total.
  Future<void> sendFile({
    required String address,
    required String fileName,
    required List<int> bytes,
    Duration timeout = const Duration(minutes: 5),
    void Function(int sent, int total)? onProgress,
  }) async {
    final frame = _frame(fileName, bytes);

    final completion = onTransferEvent
        .where((e) =>
            e.kind == BleTransferEventKind.sendComplete ||
            e.kind == BleTransferEventKind.sendFailed)
        .first
        .timeout(timeout,
            onTimeout: () => throw BleException(
                  'Timed out sending $fileName',
                ));

    final progressSub = onTransferEvent.listen((e) {
      if (e.kind == BleTransferEventKind.progress && e.total > 0) {
        onProgress?.call(e.sent, e.total);
      }
    });

    try {
      final bool queued;
      try {
        queued = await _method.invokeMethod<bool>(
              'bleSendData',
              <String, dynamic>{
                'deviceAddress': address,
                'data': frame,
              },
            ) ??
            false;
      } on PlatformException catch (e) {
        // V-012: the native layer fails closed until the link is bonded —
        // surface its pairing message rather than a generic write failure.
        completion.ignore();
        throw BleException(e.message ?? 'BLE write could not be started');
      }
      if (!queued) {
        completion.ignore();
        throw const BleException('BLE write could not be started');
      }

      final result = await completion;
      if (result.kind == BleTransferEventKind.sendFailed) {
        throw BleException(result.error ?? 'Transfer failed');
      }
    } on TimeoutException {
      rethrow;
    } finally {
      await progressSub.cancel();
    }
  }

  // ---------- Convenience ----------

  /// Receiver flow: advertise → wait for one complete incoming frame.
  Future<({String fileName, List<int> bytes})> receiveFile({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final event = onTransferEvent
        .where((e) => e.kind == BleTransferEventKind.received)
        .first
        .timeout(timeout,
            onTimeout: () => throw const BleException(
                  'Timed out waiting for an incoming transfer',
                ));
    final received = await event;
    final frame = received.frame;
    if (frame == null) {
      throw const BleException('Received an empty transfer');
    }
    return _decodeFrame(frame);
  }

  /// Scans and returns the strongest-signal peer seen within [timeout].
  Future<BleDevice?> findPeer({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final found = <String, BleDevice>{};
    final sub = onDeviceFound.listen((d) {
      final existing = found[d.address];
      if (existing == null || d.rssi > existing.rssi) found[d.address] = d;
    });
    await startScanning();
    try {
      await Future.delayed(timeout);
    } finally {
      await stopScanning();
      await sub.cancel();
    }
    if (found.isEmpty) return null;
    final best = found.values.reduce((a, b) => a.rssi >= b.rssi ? a : b);
    return best;
  }

  Future<void> shutdown() async {
    try {
      await _method.invokeMethod('bleShutdown');
    } catch (_) {}
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _discoverySub?.cancel();
    _connectionSub?.cancel();
    _dataSub?.cancel();
    _discoveredDevicesController.close();
    _connectionController.close();
    _transferController.close();
  }

  // ---------- Framing ----------

  Uint8List _frame(String fileName, List<int> bytes) =>
      BleFrame.encode(fileName: fileName, payload: bytes);

  ({String fileName, List<int> bytes}) _decodeFrame(Uint8List data) {
    final decoded = BleFrame.decode(data);
    return (fileName: decoded.fileName, bytes: decoded.payload);
  }
}

class BleDevice {
  final String address;
  final String name;
  final int rssi;
  const BleDevice(
      {required this.address, required this.name, required this.rssi});
}

class BleConnectionEvent {
  final String address;
  final bool connected;
  final String? role;
  final String? error;
  const BleConnectionEvent({
    required this.address,
    required this.connected,
    this.role,
    this.error,
  });
}

enum BleTransferEventKind { progress, sendComplete, sendFailed, received }

class BleTransferEvent {
  final BleTransferEventKind kind;
  final int sent;
  final int total;
  final Uint8List? frame;
  final String? address;
  final String? error;

  const BleTransferEvent({
    required this.kind,
    this.sent = 0,
    this.total = 0,
    this.frame,
    this.address,
    this.error,
  });
}

class BleException implements Exception {
  final String message;
  const BleException(this.message);

  @override
  String toString() => 'Bluetooth error: $message';
}
