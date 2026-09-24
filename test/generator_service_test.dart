import 'package:flutter_test/flutter_test.dart';
import 'package:firewood/services/generator_service.dart';

void main() {
  group('GeneratorService Tests', () {
    test('generatePassword returns correct length and character sets', () {
      final pwd = GeneratorService.generatePassword(
        length: 20,
        includeLowercase: true,
        includeUppercase: true,
        includeDigits: true,
        includeSymbols: true,
      );

      expect(pwd.length, equals(20));
      expect(pwd.contains(RegExp(r'[a-z]')), isTrue);
      expect(pwd.contains(RegExp(r'[A-Z]')), isTrue);
      expect(pwd.contains(RegExp(r'[0-9]')), isTrue);
    });

    test('calculateStrength returns accurate ratings', () {
      expect(GeneratorService.calculateStrength('123'), equals(0));
      expect(GeneratorService.calculateStrength('password123'),
          lessThanOrEqualTo(2));
      expect(GeneratorService.calculateStrength('C0mpl3x!P@ssw0rd#2026'),
          greaterThanOrEqualTo(3));
    });

    test('Base32 encode and decode RFC 4648 roundtrip', () {
      const original = 'JBSWY3DPEHPK3PXP'; // Base32 encoded "Hello World!"
      final bytes = GeneratorService.base32Decode(original);
      final reencoded = GeneratorService.base32Encode(bytes);

      expect(reencoded, equals(original));
    });

    test('isValidTOTPSecret validates secret strings correctly', () {
      expect(GeneratorService.isValidTOTPSecret('JBSWY3DPEHPK3PXP'), isTrue);
      expect(GeneratorService.isValidTOTPSecret('SHORT'), isFalse);
      expect(GeneratorService.isValidTOTPSecret(r'INVALID_CHARS!#$'), isFalse);
    });

    test('generatePassphrase creates passphrase with requested word count', () {
      final passphrase = GeneratorService.generatePassphrase(
        wordCount: 5,
        separator: '-',
        includeNumber: false,
      );
      final words = passphrase.split('-');
      expect(words.length, equals(5));
    });
  });
}
