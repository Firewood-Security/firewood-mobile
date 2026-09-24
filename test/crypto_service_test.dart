@Timeout(Duration(minutes: 5))
import 'package:flutter_test/flutter_test.dart';
import 'package:firewood/security/crypto_service.dart';

void main() {
  group('CryptoService Tests', () {
    late CryptoService crypto;

    setUp(() {
      crypto = CryptoService();
    });

    test('generateSalt returns 16-byte random salt', () {
      final salt1 = crypto.generateSalt();
      final salt2 = crypto.generateSalt();

      expect(salt1.length, equals(16));
      expect(salt2.length, equals(16));
      expect(salt1, isNot(equals(salt2)));
    });

    test('deriveKey creates consistent key from same password and salt', () async {
      final salt = crypto.generateSalt();
      const password = 'CorrectHorseBatteryStaple123!';

      final key1 = await crypto.deriveKey(password, salt);
      final key2 = await crypto.deriveKey(password, salt);

      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();

      expect(bytes1, equals(bytes2));
      expect(bytes1.length, equals(32)); // 256-bit key
    });

    test('deriveKey creates different keys for different passwords or salts', () async {
      final salt1 = crypto.generateSalt();
      final salt2 = crypto.generateSalt();
      const password = 'MySecretPassword';

      final key1 = await crypto.deriveKey(password, salt1);
      final key2 = await crypto.deriveKey(password, salt2);
      final key3 = await crypto.deriveKey('DifferentPassword', salt1);

      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();
      final bytes3 = await key3.extractBytes();

      expect(bytes1, isNot(equals(bytes2)));
      expect(bytes1, isNot(equals(bytes3)));
    });

    test('encrypt and decrypt roundtrip works correctly for UTF-8 strings', () async {
      final salt = crypto.generateSalt();
      final key = await crypto.deriveKey('VaultMasterPassword', salt);
      const plaintext = 'Secret Bank Account Credentials 🔐';

      final result = await crypto.encryptString(plaintext, key);
      expect(result.ciphertext, isNotEmpty);
      expect(result.nonce.length, equals(24)); // XChaCha20 nonce

      final decrypted = await crypto.decryptString(result.ciphertext, result.nonce, key);
      expect(decrypted, equals(plaintext));
    });

    test('decrypt fails with wrong key', () async {
      final salt = crypto.generateSalt();
      final key = await crypto.deriveKey('Password1', salt);
      final wrongKey = await crypto.deriveKey('Password2', salt);

      final result = await crypto.encryptString('Super Secret Data', key);

      expect(
        () async => await crypto.decryptString(result.ciphertext, result.nonce, wrongKey),
        throwsA(anything),
      );
    });

    // --- Phase 3 security negatives (REQ-CRYPTO-01) ---

    test('parameter pinning: 16 B salt, 24 B nonce, 32 B key, 16 B MAC overhead', () async {
      final salt = crypto.generateSalt();
      expect(salt.length, equals(16));
      final key = await crypto.deriveKey('PinMe', salt);
      expect((await key.extractBytes()).length, equals(32));
      const msg = '0123456789ABCDEF'; // 16 bytes UTF-8
      final enc = await crypto.encryptString(msg, key);
      expect(enc.nonce.length, equals(24));
      // ciphertext = plaintext + 16-byte Poly1305 tag
      expect(enc.ciphertext.length, equals(16 + 16));
    });

    test('decrypt rejects tampered ciphertext', () async {
      final key = await crypto.deriveKey('TamperTest', crypto.generateSalt());
      final enc = await crypto.encryptString('Do not touch', key);
      final tampered = List<int>.from(enc.ciphertext);
      tampered[0] ^= 0xFF;
      expect(
        () async => await crypto.decrypt(tampered, enc.nonce, key),
        throwsA(anything),
      );
    });

    test('decrypt rejects truncated and short inputs', () async {
      final key = await crypto.deriveKey('TruncateTest', crypto.generateSalt());
      final enc = await crypto.encryptString('Somewhat longer secret value', key);
      final truncated = enc.ciphertext.sublist(0, enc.ciphertext.length - 1);
      expect(
        () async => await crypto.decrypt(truncated, enc.nonce, key),
        throwsA(anything),
      );
      expect(
        () async => await crypto.decrypt([1, 2, 3], enc.nonce, key),
        throwsA(anything),
      );
    });

    test('decrypt rejects wrong nonce', () async {
      final key = await crypto.deriveKey('NonceTest', crypto.generateSalt());
      final enc = await crypto.encryptString('Nonce-bound data', key);
      final other = await crypto.encryptString('Other', key);
      expect(
        () async => await crypto.decrypt(enc.ciphertext, other.nonce, key),
        throwsA(anything),
      );
    });

    test('empty plaintext roundtrips', () async {
      final key = await crypto.deriveKey('EmptyTest', crypto.generateSalt());
      final enc = await crypto.encryptString('', key);
      expect(await crypto.decryptString(enc.ciphertext, enc.nonce, key), equals(''));
    });

    test('deriveSubkey is deterministic and domain-separated', () async {
      final master = await crypto.deriveKey('MasterKey', crypto.generateSalt());
      final a1 = await crypto.deriveSubkey(master, 'backup-file');
      final a2 = await crypto.deriveSubkey(master, 'backup-file');
      final b = await crypto.deriveSubkey(master, 'other-purpose');
      final ab = await a1.extractBytes();
      expect(await a2.extractBytes(), equals(ab));
      expect(ab.length, equals(32));
      expect(await b.extractBytes(), isNot(equals(ab)));
    });

    test('fresh encryption never reuses a nonce', () async {
      final key = await crypto.deriveKey('NonceReuse', crypto.generateSalt());
      final e1 = await crypto.encryptString('same', key);
      final e2 = await crypto.encryptString('same', key);
      expect(e1.nonce, isNot(equals(e2.nonce)));
      expect(e1.ciphertext, isNot(equals(e2.ciphertext)));
    });
  });
}
