// services/generator_service.dart
// Password generator and TOTP generator

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:otp/otp.dart';

class GeneratorService {
  static const String _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const String _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _digits = '0123456789';
  static const String _symbols = r'!@#$%^&*()_+-=[]{}|;:,.<>?';

  /// Generate a secure random password
  static String generatePassword({
    int length = 16,
    bool includeLowercase = true,
    bool includeUppercase = true,
    bool includeDigits = true,
    bool includeSymbols = true,
    bool excludeSimilar = true,
    bool excludeAmbiguous = false,
  }) {
    if (length < 4) length = 4;
    if (length > 128) length = 128;

    var charset = '';
    if (includeLowercase) charset += _lowercase;
    if (includeUppercase) charset += _uppercase;
    if (includeDigits) charset += _digits;
    if (includeSymbols) charset += _symbols;

    if (charset.isEmpty) {
      charset = _lowercase + _uppercase + _digits;
    }

    if (excludeSimilar) {
      charset = charset.replaceAll(RegExp(r'[il1Lo0O]'), '');
    }
    if (excludeAmbiguous) {
      charset = charset.replaceAll(RegExp(r'[\{\}\[\]\(\)\/\\"' "`" r'~,;\.<>]'), '');
    }

    if (charset.isEmpty) {
      charset = _lowercase + _uppercase + _digits;
    }

    final random = Random.secure();
    final password = StringBuffer();

    // Ensure at least one character from each selected category if available
    if (includeLowercase && _hasMatch(charset, RegExp(r'[a-z]'))) {
      password.write(_randomFrom(_lowercase, random));
    }
    if (includeUppercase && _hasMatch(charset, RegExp(r'[A-Z]'))) {
      password.write(_randomFrom(_uppercase, random));
    }
    if (includeDigits && _hasMatch(charset, RegExp(r'[0-9]'))) {
      password.write(_randomFrom(_digits, random));
    }
    if (includeSymbols && _hasMatch(charset, RegExp(r'[^a-zA-Z0-9]'))) {
      password.write(_randomFrom(_symbols, random));
    }

    // Fill the rest
    while (password.length < length) {
      password.write(_randomFrom(charset, random));
    }

    // Shuffle the result
    final chars = password.toString().split('');
    chars.shuffle(random);
    return chars.join();
  }

  static String _randomFrom(String charset, Random random) {
    return charset[random.nextInt(charset.length)];
  }

  static bool _hasMatch(String s, RegExp regExp) => regExp.hasMatch(s);

  /// Calculate password strength (0-4)
  static int calculateStrength(String password) {
    if (password.length < 6) return 0;
    int score = 0;
    
    // Length
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (password.length >= 24) score++;
    
    // Character variety
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[^a-zA-Z0-9]'))) score++;

    if (score >= 7) return 4;
    if (score >= 5) return 3;
    if (score >= 3) return 2;
    if (score >= 1) return 1;
    return 0;
  }

  static String getStrengthLabel(int strength) {
    switch (strength) {
      case 0: return 'Very Weak';
      case 1: return 'Weak';
      case 2: return 'Fair';
      case 3: return 'Strong';
      case 4: return 'Very Strong';
      default: return 'Unknown';
    }
  }

  static Color getStrengthColor(int strength) {
    switch (strength) {
      case 0: return Colors.red;
      case 1: return Colors.orange;
      case 2: return Colors.amber;
      case 3: return Colors.lightGreen;
      case 4: return Colors.green;
      default: return Colors.grey;
    }
  }

  /// Base32 decode RFC 4648
  static List<int> base32Decode(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final clean = input.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    final bytes = <int>[];
    int buffer = 0;
    int bits = 0;

    for (int i = 0; i < clean.length; i++) {
      final index = alphabet.indexOf(clean[i]);
      if (index == -1) continue;
      buffer = (buffer << 5) | index;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        bytes.add((buffer >> bits) & 0xFF);
      }
    }
    return bytes;
  }

  /// Base32 encode RFC 4648
  static String base32Encode(List<int> bytes) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final buffer = StringBuffer();
    int current = 0;
    int bits = 0;

    for (final byte in bytes) {
      current = (current << 8) | (byte & 0xFF);
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        buffer.write(alphabet[(current >> bits) & 0x1F]);
      }
    }

    if (bits > 0) {
      buffer.write(alphabet[(current << (5 - bits)) & 0x1F]);
    }

    return buffer.toString();
  }

  /// Generate TOTP code from secret
  static String generateTOTP({
    required String secret,
    int digits = 6,
    int period = 30,
    String algorithm = 'SHA1',
  }) {
    // Normalize secret (remove spaces, uppercase)
    final normalizedSecret = secret.replaceAll(' ', '').toUpperCase();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    
    Algorithm algo;
    switch (algorithm.toUpperCase()) {
      case 'SHA256':
        algo = Algorithm.SHA256;
        break;
      case 'SHA512':
        algo = Algorithm.SHA512;
        break;
      default:
        algo = Algorithm.SHA1;
    }
    
    return OTP.generateTOTPCodeString(
      normalizedSecret,
      nowMs,
      interval: period,
      length: digits,
      algorithm: algo,
      isGoogle: true,
    );
  }

  static int getTOTPRemainingSeconds({int period = 30}) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    return (period - (now % period)).ceil();
  }

  /// Generate a random base32 secret for TOTP
  static String generateTOTPSecret({int length = 32}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base32Encode(bytes).replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ').trim();
  }

  /// Validate TOTP secret format
  static bool isValidTOTPSecret(String secret) {
    final normalized = secret.replaceAll(' ', '').toUpperCase();
    if (normalized.length < 16 || normalized.length > 64) return false;
    return RegExp(r'^[A-Z2-7]+$').hasMatch(normalized);
  }

  /// Generate passphrase (diceware-style)
  static String generatePassphrase({
    int wordCount = 4,
    String separator = '-',
    bool capitalize = false,
    bool includeNumber = true,
  }) {
    const words = [
      'apple', 'banana', 'cherry', 'diamond', 'elephant', 'forest', 'guitar',
      'horizon', 'island', 'journey', 'keyboard', 'laptop', 'mountain', 'notebook',
      'ocean', 'pencil', 'quartz', 'river', 'sunset', 'tiger', 'umbrella',
      'violin', 'waterfall', 'xylophone', 'yellow', 'zebra', 'anchor', 'bridge',
      'crystal', 'dolphin', 'eagle', 'feather', 'garden', 'harmony', 'inspire',
      'jazz', 'kangaroo', 'lighthouse', 'meadow', 'nebula', 'orchard', 'penguin',
      'quantum', 'rainbow', 'starlight', 'thunder', 'universe', 'velvet', 'whisper',
      'xenon', 'yesterday', 'zenith', 'aurora', 'breeze', 'compass', 'dawn',
      'echo', 'flame', 'glacier', 'horizon', 'infinity', 'jade', 'karma', 'lunar',
      'mirror', 'nature', 'opal', 'peace', 'quest', 'radiant', 'serenity', 'tide',
      'unity', 'vivid', 'wonder', 'xenial', 'yearn', 'zephyr',
    ];

    final random = Random.secure();
    final selected = <String>[];
    
    for (int i = 0; i < wordCount; i++) {
      selected.add(words[random.nextInt(words.length)]);
    }

    var result = selected.join(separator);
    
    if (capitalize) {
      result = result.split(separator).map((w) => w[0].toUpperCase() + w.substring(1)).join(separator);
    }
    
    if (includeNumber) {
      result += '$separator${random.nextInt(10000).toString().padLeft(4, '0')}';
    }
    
    return result;
  }
}