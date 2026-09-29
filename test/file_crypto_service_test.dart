// test/file_crypto_service_test.dart
// Round-trip, wrong-password and tamper tests for single-file .firewood containers.

// Argon2id is deliberately expensive (64 MB); give each case room when the
// whole suite runs its test files in parallel.
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:firewood/services/file_crypto_service.dart';

void main() {
  final service = FileCryptoService();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('firewood_file_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('V-031 sanitizeFileName (hostile BLE frame names)', () {
    test('path separators and traversal cannot survive', () {
      for (final hostile in [
        '../../.bashrc',
        '..%2F..%2Fetc%2Fpasswd',
        'a/b\\c',
        '....//....//x',
      ]) {
        final safe = FileCryptoService.sanitizeFileName(hostile);
        expect(safe, isNot(contains('/')), reason: hostile);
        expect(safe, isNot(contains('\\')), reason: hostile);
        expect(safe, isNotEmpty, reason: hostile);
        expect(safe, isNot(equals('.')), reason: hostile);
        expect(safe, isNot(equals('..')), reason: hostile);
        expect(safe, isNot(startsWith('.')),
            reason: '$hostile must not plant a hidden file');
      }
    });

    test('degenerate names map to unnamed; normal names pass through', () {
      expect(FileCryptoService.sanitizeFileName('..'), 'unnamed');
      expect(FileCryptoService.sanitizeFileName('.'), 'unnamed');
      expect(FileCryptoService.sanitizeFileName(''), 'unnamed');
      expect(FileCryptoService.sanitizeFileName('.bashrc'), 'bashrc');
      expect(FileCryptoService.sanitizeFileName('notes.pdf'), 'notes.pdf');
      expect(FileCryptoService.sanitizeFileName('my report (2).pdf'),
          'my_report__2_.pdf');
    });
  });

  test('encrypts and decrypts file bytes with metadata', () async {
    final bytes = List<int>.generate(4096, (i) => i % 256);

    final result = await service.encryptFileToFirewood(
      masterPassword: 'correct horse battery staple',
      bytes: bytes,
      fileName: 'holiday-photo.jpg',
      mimeType: 'image/jpeg',
      outputPath: '${tempDir.path}/holiday-photo',
    );

    expect(result.path.toLowerCase().endsWith('.firewood'), isTrue);
    expect(await File(result.path).exists(), isTrue);
    expect(result.metadata.size, bytes.length);
    expect(result.metadata.sha256, hasLength(64));

    final content = await service.decryptFirewoodFile(
      masterPassword: 'correct horse battery staple',
      path: result.path,
    );

    expect(content.bytes, equals(bytes));
    expect(content.metadata.fileName, 'holiday-photo.jpg');
    expect(content.metadata.mimeType, 'image/jpeg');
  });

  test('rejects an incorrect master password', () async {
    final result = await service.encryptFileToFirewood(
      masterPassword: 'right-password',
      bytes: [1, 2, 3, 4, 5],
      fileName: 'a.bin',
      outputPath: '${tempDir.path}/secret',
    );

    expect(
      () => service.decryptFirewoodFile(
        masterPassword: 'wrong-password',
        path: result.path,
      ),
      throwsA(isA<FileCryptoException>()),
    );
  });

  test('detects tampering with the ciphertext', () async {
    final result = await service.encryptFileToFirewood(
      masterPassword: 'pw-123456',
      bytes: List<int>.generate(128, (i) => i),
      fileName: 'b.bin',
      outputPath: '${tempDir.path}/tamper',
    );

    final file = File(result.path);
    final data = await file.readAsBytes();
    data[data.length - 1] ^= 0xFF; // flip a bit in the Poly1305 tag
    await file.writeAsBytes(data, flush: true);

    expect(
      () => service.decryptFirewoodFile(
        masterPassword: 'pw-123456',
        path: result.path,
      ),
      throwsA(isA<FileCryptoException>()),
    );
  });
}
