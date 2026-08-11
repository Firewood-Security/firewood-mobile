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
  });
}
