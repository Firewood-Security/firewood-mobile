// p2p/transfer_models.dart
// Immutable data transfer models for Firewood P2P system

import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Connection and session lifecycle states
enum TransferState {
  idle,
  discovering,
  connecting,
  handshake,
  encrypting,
  sending,
  receiving,
  decrypting,
  completed,
  failed,
}

/// Type of content being transferred
enum TransferType {
  singleItem,
  fullVault,
}

/// Handshake packet containing ephemeral public key
@immutable
class HandshakePacket {
  final String deviceId;
  final String deviceName;
  final String publicKeyBase64;
  final int timestamp;

  const HandshakePacket({
    required this.deviceId,
    required this.deviceName,
    required this.publicKeyBase64,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'publicKeyBase64': publicKeyBase64,
        'timestamp': timestamp,
      };

  factory HandshakePacket.fromJson(Map<String, dynamic> json) => HandshakePacket(
        deviceId: json['deviceId'] as String,
        deviceName: json['deviceName'] as String,
        publicKeyBase64: json['publicKeyBase64'] as String,
        timestamp: json['timestamp'] as int,
      );

  String serialize() => jsonEncode(toJson());

  factory HandshakePacket.deserialize(String raw) =>
      HandshakePacket.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Metadata describing transfer contents before accepting
@immutable
class TransferMetadata {
  final String transferId;
  final TransferType type;
  final String title;
  final String itemType; // 'login', 'card', 'identity', 'note', 'vault'
  final int payloadSizeBytes;

  const TransferMetadata({
    required this.transferId,
    required this.type,
    required this.title,
    required this.itemType,
    required this.payloadSizeBytes,
  });

  Map<String, dynamic> toJson() => {
        'transferId': transferId,
        'type': type.name,
        'title': title,
        'itemType': itemType,
        'payloadSizeBytes': payloadSizeBytes,
      };

  factory TransferMetadata.fromJson(Map<String, dynamic> json) => TransferMetadata(
        transferId: json['transferId'] as String,
        type: TransferType.values.firstWhere((e) => e.name == json['type']),
        title: json['title'] as String,
        itemType: json['itemType'] as String,
        payloadSizeBytes: json['payloadSizeBytes'] as int,
      );
}

/// Transfer Request sent from initiator to recipient
@immutable
class TransferRequest {
  final String senderId;
  final String senderName;
  final TransferMetadata metadata;

  const TransferRequest({
    required this.senderId,
    required this.senderName,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderName': senderName,
        'metadata': metadata.toJson(),
      };

  factory TransferRequest.fromJson(Map<String, dynamic> json) => TransferRequest(
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        metadata: TransferMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      );

  String serialize() => jsonEncode(toJson());

  factory TransferRequest.deserialize(String raw) =>
      TransferRequest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Recipient response (Accepted / Rejected)
@immutable
class TransferResponse {
  final String transferId;
  final bool accepted;
  final String? reason;

  const TransferResponse({
    required this.transferId,
    required this.accepted,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
        'transferId': transferId,
        'accepted': accepted,
        'reason': reason,
      };

  factory TransferResponse.fromJson(Map<String, dynamic> json) => TransferResponse(
        transferId: json['transferId'] as String,
        accepted: json['accepted'] as bool,
        reason: json['reason'] as String?,
      );

  String serialize() => jsonEncode(toJson());

  factory TransferResponse.deserialize(String raw) =>
      TransferResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Encrypted payload packet sent over transport
@immutable
class TransferPacket {
  final String transferId;
  final String encryptedPayloadBase64;
  final String nonceBase64;
  final String macBase64;

  const TransferPacket({
    required this.transferId,
    required this.encryptedPayloadBase64,
    required this.nonceBase64,
    required this.macBase64,
  });

  Map<String, dynamic> toJson() => {
        'transferId': transferId,
        'encryptedPayloadBase64': encryptedPayloadBase64,
        'nonceBase64': nonceBase64,
        'macBase64': macBase64,
      };

  factory TransferPacket.fromJson(Map<String, dynamic> json) => TransferPacket(
        transferId: json['transferId'] as String,
        encryptedPayloadBase64: json['encryptedPayloadBase64'] as String,
        nonceBase64: json['nonceBase64'] as String,
        macBase64: json['macBase64'] as String,
      );

  String serialize() => jsonEncode(toJson());

  factory TransferPacket.deserialize(String raw) =>
      TransferPacket.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
