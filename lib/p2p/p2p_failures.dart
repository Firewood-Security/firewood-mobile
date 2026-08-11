// p2p/p2p_failures.dart
// Typed failure hierarchy for Firewood P2P transfer system

import 'package:flutter/foundation.dart';

@immutable
abstract class P2PFailure implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const P2PFailure(this.message, {this.code, this.cause});

  @override
  String toString() => '$runtimeType: $message${code != null ? ' (Code: $code)' : ''}';
}

class HandshakeFailure extends P2PFailure {
  const HandshakeFailure(super.message, {super.code, super.cause});
}

class TransportFailure extends P2PFailure {
  const TransportFailure(super.message, {super.code, super.cause});
}

class TimeoutFailure extends P2PFailure {
  const TimeoutFailure(super.message, {super.code, super.cause});
}

class CryptoFailure extends P2PFailure {
  const CryptoFailure(super.message, {super.code, super.cause});
}

class ImportFailure extends P2PFailure {
  const ImportFailure(super.message, {super.code, super.cause});
}

class ExportFailure extends P2PFailure {
  const ExportFailure(super.message, {super.code, super.cause});
}

/// Thrown when Bluetooth / NearbyConnections is not available on this device.
class BluetoothUnavailableFailure extends P2PFailure {
  const BluetoothUnavailableFailure(super.message, {super.code, super.cause});
}

/// Thrown when neither Bluetooth nor a reachable LAN network could be detected.
class NoTransportAvailableFailure extends P2PFailure {
  const NoTransportAvailableFailure(super.message, {super.code, super.cause});
}
