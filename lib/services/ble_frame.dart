// Wire format for Firewood BLE transfers.
//
// Frame layout (identical on Android, desktop and in the Kotlin
// `BleFrameAssembler`):
// ```
//   [0..3]  u32 big-endian length of the payload that follows the name
//   [4..5]  u16 big-endian file-name length
//   [6..]   UTF-8 file name, immediately followed by the payload
// ```
//
// The declared lengths let the receiver know when a multi-packet transfer is
// complete: BLE moves 20 bytes per packet by default, so a vault arrives as
// hundreds of writes that must be buffered and reassembled.

import 'dart:convert';
import 'dart:typed_data';

class BleFrame {
  const BleFrame._();

  static const int headerLength = 6;

  /// Encodes [payload] as a frame carrying [fileName].
  static Uint8List encode({
    required String fileName,
    required List<int> payload,
  }) {
    final nameBytes = utf8.encode(fileName);
    if (nameBytes.length > 0xFFFF) {
      throw BleFrameException('File name is too long for the BLE frame');
    }
    if (payload.length > 0xFFFFFFFF) {
      throw BleFrameException('Payload is too long for the BLE frame');
    }

    final frame = Uint8List(headerLength + nameBytes.length + payload.length);
    final view = ByteData.sublistView(frame);
    view.setUint32(0, payload.length);
    view.setUint16(4, nameBytes.length);
    frame.setAll(headerLength, nameBytes);
    frame.setAll(headerLength + nameBytes.length, payload);
    return frame;
  }

  /// Decodes a complete frame back into its name and payload.
  static ({String fileName, Uint8List payload}) decode(Uint8List frame) {
    if (frame.length < headerLength) {
      throw BleFrameException('Frame is shorter than its header');
    }
    final view = ByteData.sublistView(frame);
    final payloadLength = view.getUint32(0);
    final nameLength = view.getUint16(4);
    if (frame.length < headerLength + nameLength + payloadLength) {
      throw BleFrameException('Frame is truncated');
    }
    return (
      fileName:
          utf8.decode(frame.sublist(headerLength, headerLength + nameLength)),
      payload: Uint8List.sublistView(
        frame,
        headerLength + nameLength,
        headerLength + nameLength + payloadLength,
      ),
    );
  }

  /// Total frame length declared by the first [headerLength] bytes, or null when
  /// the header has not fully arrived. Mirrors `BleFrameAssembler.declaredLength`.
  static int? declaredLength(Uint8List bytes) {
    if (bytes.length < headerLength) return null;
    final view = ByteData.sublistView(bytes);
    return headerLength + view.getUint16(4) + view.getUint32(0);
  }

  /// Splits [frame] into [chunkSize]-byte pieces, as the native sender does.
  /// Exposed so tests can prove chunked delivery reassembles identically.
  static List<Uint8List> split(Uint8List frame, int chunkSize) {
    if (chunkSize < 20) {
      throw BleFrameException(
          'chunkSize must be at least 20 bytes (ATT_MTU 23)');
    }
    final chunks = <Uint8List>[];
    for (var offset = 0; offset < frame.length; offset += chunkSize) {
      final end = offset + chunkSize;
      chunks.add(frame.sublist(
        offset,
        end > frame.length ? frame.length : end,
      ));
    }
    return chunks;
  }
}

class BleFrameException implements Exception {
  final String message;
  const BleFrameException(this.message);

  @override
  String toString() => 'BleFrameException: $message';
}
