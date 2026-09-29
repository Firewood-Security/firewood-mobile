// test/ble_frame_test.dart
// Wire-format tests for the BLE transfer frame. These are the bytes that the
// Kotlin `BleFrameAssembler` reassembles on the receiving phone, so the layout
// is asserted explicitly rather than only round-tripped.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:firewood/services/ble_frame.dart';

void main() {
  group('encode', () {
    test('writes a big-endian u32 payload length and u16 name length', () {
      final frame = BleFrame.encode(
        fileName: 'ab.firewood',
        payload: List<int>.filled(0x010203, 0xAB),
      );

      // u32 payload length, big endian.
      expect(frame.sublist(0, 4), [0x00, 0x01, 0x02, 0x03]);
      // u16 name length, big endian ("ab.firewood" = 11 bytes).
      expect(frame.sublist(4, 6), [0x00, 0x0B]);
      expect(
        String.fromCharCodes(frame.sublist(6, 17)),
        'ab.firewood',
      );
      expect(frame.length, BleFrame.headerLength + 11 + 0x010203);
    });

    test('keeps binary payloads byte-exact', () {
      final payload = List<int>.generate(1024, (i) => (i * 7) % 256);
      final frame = BleFrame.encode(fileName: 'x', payload: payload);
      final decoded = BleFrame.decode(frame);

      expect(decoded.payload, payload);
      expect(decoded.fileName, 'x');
    });

    test('handles an empty payload', () {
      final frame = BleFrame.encode(fileName: 'empty', payload: const []);
      final decoded = BleFrame.decode(frame);
      expect(decoded.fileName, 'empty');
      expect(decoded.payload, isEmpty);
      expect(frame.length, BleFrame.headerLength + 5);
    });

    test('handles a multi-byte UTF-8 name', () {
      final frame =
          BleFrame.encode(fileName: '🔥vault.firewood', payload: [1, 2, 3]);
      final decoded = BleFrame.decode(frame);
      expect(decoded.fileName, '🔥vault.firewood');
      expect(decoded.payload, [1, 2, 3]);
    });
  });

  group('decode', () {
    test('rejects a frame shorter than the header', () {
      expect(
        () => BleFrame.decode(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<BleFrameException>()),
      );
    });

    test('rejects a truncated payload', () {
      final frame = BleFrame.encode(fileName: 'name', payload: [1, 2, 3, 4, 5]);
      expect(
        () => BleFrame.decode(frame.sublist(0, frame.length - 2)),
        throwsA(isA<BleFrameException>()),
      );
    });
  });

  group('declaredLength', () {
    test('is null until the whole header has arrived', () {
      final frame = BleFrame.encode(fileName: 'name', payload: [1, 2, 3, 4]);
      for (var i = 0; i < BleFrame.headerLength - 1; i++) {
        expect(BleFrame.declaredLength(frame.sublist(0, i + 1)), isNull);
      }
      expect(
        BleFrame.declaredLength(frame.sublist(0, BleFrame.headerLength)),
        frame.length,
      );
    });
  });

  group('split + reassemble', () {
    // This mirrors what the native layer does: write a frame in MTU-sized
    // chunks and let the receiver buffer until the declared length is met.
    test('a chunked transfer rebuilds the original frame', () {
      final payload = List<int>.generate(4096, (i) => i % 256);
      final frame =
          BleFrame.encode(fileName: 'vault.firewood', payload: payload);

      for (final chunkSize in [20, 100, 244, 509]) {
        final chunks = BleFrame.split(frame, chunkSize);
        final reassembled = BytesBuilder(copy: false);
        int? expected;
        Uint8List? completed;

        for (final chunk in chunks) {
          reassembled.add(chunk);
          final buffer = reassembled.toBytes();
          expected ??= BleFrame.declaredLength(buffer);
          if (expected != null && buffer.length >= expected) {
            completed = buffer;
            break;
          }
        }

        expect(completed, isNotNull,
            reason: 'frame never completed at $chunkSize');
        expect(completed, orderedEquals(frame),
            reason: 'mismatch at chunk $chunkSize');
      }
    });

    test('refuses chunk sizes below the 20-byte ATT payload minimum', () {
      expect(
        () => BleFrame.split(Uint8List(10), 19),
        throwsA(isA<BleFrameException>()),
      );
    });
  });
}
