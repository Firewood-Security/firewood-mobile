// services/generator_service.dart
// Advanced Password, Diceware Passphrase, PIN and RFC 6238 TOTP Generator with Cryptographic Strength Assessment

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:otp/otp.dart';

class StrengthResult {
  final int score; // 0 to 4
  final String label;
  final Color color;
  final double entropyBits;
  final String crackTimeEstimate;
  final String recommendation;

  const StrengthResult({
    required this.score,
    required this.label,
    required this.color,
    required this.entropyBits,
    required this.crackTimeEstimate,
    required this.recommendation,
  });
}

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
      charset =
          charset.replaceAll(RegExp(r'[\{\}\[\]\(\)\/\\"' "`" r'~,;\.<>]'), '');
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

  /// Generate a secure numeric PIN
  static String generatePIN({int length = 6}) {
    if (length < 4) length = 4;
    if (length > 16) length = 16;
    final random = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(random.nextInt(10));
    }
    return buffer.toString();
  }

  /// Generate Diceware-style passphrase
  static String generatePassphrase({
    int wordCount = 4,
    String separator = '-',
    bool capitalize = false,
    bool includeNumber = true,
  }) {
    if (wordCount < 3) wordCount = 3;
    if (wordCount > 10) wordCount = 10;

    const words = [
      'abandon',
      'ability',
      'absent',
      'absorb',
      'abstract',
      'academy',
      'access',
      'accident',
      'account',
      'accuse',
      'achieve',
      'acoustic',
      'acquire',
      'across',
      'action',
      'actor',
      'actress',
      'adapt',
      'addition',
      'address',
      'adjust',
      'admit',
      'adult',
      'advance',
      'advice',
      'aerobic',
      'afford',
      'afraid',
      'agent',
      'agree',
      'ahead',
      'aim',
      'airport',
      'alarm',
      'album',
      'alcohol',
      'alert',
      'alien',
      'allied',
      'almond',
      'almost',
      'alone',
      'alpha',
      'already',
      'alter',
      'always',
      'amateur',
      'amazing',
      'among',
      'amount',
      'amused',
      'analyst',
      'anchor',
      'ancient',
      'anger',
      'angle',
      'angry',
      'animal',
      'ankle',
      'announce',
      'annual',
      'another',
      'answer',
      'antenna',
      'antique',
      'anxiety',
      'anybody',
      'apart',
      'apology',
      'appear',
      'apple',
      'approve',
      'april',
      'arch',
      'arctic',
      'area',
      'arena',
      'argue',
      'armour',
      'army',
      'around',
      'arrange',
      'arrest',
      'arrive',
      'arrow',
      'artist',
      'aspect',
      'assault',
      'asset',
      'assist',
      'assume',
      'asthma',
      'athlete',
      'atom',
      'attack',
      'attend',
      'attitude',
      'attract',
      'auction',
      'audit',
      'august',
      'aunt',
      'author',
      'auto',
      'autumn',
      'average',
      'avocado',
      'avoid',
      'awake',
      'aware',
      'away',
      'awesome',
      'awful',
      'awkward',
      'axis',
      'baby',
      'bachelor',
      'bacon',
      'badge',
      'bag',
      'balance',
      'balcony',
      'ball',
      'bamboo',
      'banana',
      'banner',
      'bar',
      'barely',
      'bargain',
      'barrel',
      'base',
      'basic',
      'basket',
      'battle',
      'beach',
      'beacon',
      'beam',
      'beauty',
      'because',
      'become',
      'beef',
      'before',
      'begin',
      'behave',
      'behind',
      'belief',
      'below',
      'belt',
      'bench',
      'benefit',
      'best',
      'betray',
      'better',
      'between',
      'beyond',
      'bicycle',
      'bid',
      'bike',
      'bind',
      'biology',
      'bird',
      'birth',
      'bitter',
      'black',
      'blade',
      'blame',
      'blanket',
      'blast',
      'bleak',
      'bless',
      'blind',
      'blood',
      'blossom',
      'blouse',
      'blue',
      'blur',
      'blush',
      'board',
      'boat',
      'body',
      'boil',
      'bomb',
      'bone',
      'bonus',
      'book',
      'boost',
      'border',
      'boring',
      'borrow',
      'boss',
      'bottom',
      'bounce',
      'box',
      'boy',
      'bracket',
      'brain',
      'brand',
      'brass',
      'brave',
      'bread',
      'breeze',
      'brick',
      'bridge',
      'brief',
      'bright',
      'bring',
      'brisk',
      'broccoli',
      'broken',
      'bronze',
      'broom',
      'brother',
      'brown',
      'brush',
      'bubble',
      'buddy',
      'budget',
      'buffalo',
      'build',
      'bulb',
      'bulk',
      'bullet',
      'bundle',
      'bunker',
      'burden',
      'burger',
      'burst',
      'bus',
      'business',
      'busy',
      'butter',
      'buyer',
      'cabin',
      'cable',
      'cactus',
      'cage',
      'cake',
      'call',
      'calm',
      'camera',
      'camp',
      'canal',
      'cancel',
      'candy',
      'cannon',
      'canoe',
      'canvas',
      'canyon',
      'capable',
      'capital',
      'captain',
      'carbon',
      'card',
      'cargo',
      'carpet',
      'carry',
      'cart',
      'case',
      'cash',
      'casino',
      'castle',
      'casual',
      'cat',
      'catalog',
      'catch',
      'category',
      'cattle',
      'caught',
      'cause',
      'caution',
      'cave',
      'ceiling',
      'celery',
      'cement',
      'census',
      'century',
      'cereal',
      'certain',
      'chair',
      'chalk',
      'champion',
      'change',
      'chaos',
      'chapter',
      'charge',
      'chase',
      'chat',
      'cheap',
      'check',
      'cheese',
      'chef',
      'cherry',
      'chest',
      'chicken',
      'chief',
      'child',
      'chimney',
      'choice',
      'choose',
      'chronic',
      'chuckle',
      'chunk',
      'churn',
      'cigar',
      'cinnamon',
      'circle',
      'citizen',
      'city',
      'civil',
      'claim',
      'clap',
      'clarify',
      'claw',
      'clay',
      'clean',
      'clerk',
      'clever',
      'click',
      'client',
      'cliff',
      'climb',
      'clinic',
      'clip',
      'clock',
      'clog',
      'close',
      'cloth',
      'cloud',
      'clown',
      'club',
      'clump',
      'cluster',
      'clutch',
      'coach',
      'coast',
      'coconut',
      'code',
      'coffee',
      'coil',
      'coin',
      'collect',
      'color',
      'column',
      'combine',
      'come',
      'comfort',
      'comic',
      'common',
      'company',
      'concert',
      'conduct',
      'confirm',
      'congress',
      'connect',
      'consider',
      'control',
      'convince',
      'cook',
      'cool',
      'copper',
      'copy',
      'coral',
      'core',
      'corn',
      'correct',
      'cost',
      'cotton',
      'couch',
      'country',
      'couple',
      'course',
      'cousin',
      'cover',
      'coyote',
      'crack',
      'cradle',
      'craft',
      'cram',
      'crane',
      'crash',
      'crater',
      'crawl',
      'crazy',
      'cream',
      'credit',
      'creek',
      'crew',
      'cricket',
      'crime',
      'crisp',
      'critic',
      'crop',
      'cross',
      'crouch',
      'crowd',
      'crucial',
      'cruel',
      'cruise',
      'crumble',
      'crunch',
      'crush',
      'cry',
      'crystal',
      'cube',
      'culture',
      'cup',
      'cupboard',
      'curious',
      'current',
      'curtain',
      'curve',
      'cushion',
      'custom',
      'cute',
      'cycle',
      'cylinder',
    ];

    final random = Random.secure();
    final selected = <String>[];

    for (int i = 0; i < wordCount; i++) {
      selected.add(words[random.nextInt(words.length)]);
    }

    var result = selected.join(separator);

    if (capitalize) {
      result = result
          .split(separator)
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
          .join(separator);
    }

    if (includeNumber) {
      result += '$separator${random.nextInt(10000).toString().padLeft(4, '0')}';
    }

    return result;
  }

  static String _randomFrom(String charset, Random random) {
    return charset[random.nextInt(charset.length)];
  }

  static bool _hasMatch(String s, RegExp regExp) => regExp.hasMatch(s);

  /// Calculate password strength & entropy evaluation
  static StrengthResult evaluateStrength(String password) {
    if (password.isEmpty) {
      return const StrengthResult(
        score: 0,
        label: 'Empty',
        color: Colors.grey,
        entropyBits: 0,
        crackTimeEstimate: 'Instant',
        recommendation: 'Enter a password to evaluate strength.',
      );
    }

    // 1. Calculate pool size for entropy calculation
    int poolSize = 0;
    if (password.contains(RegExp(r'[a-z]'))) poolSize += 26;
    if (password.contains(RegExp(r'[A-Z]'))) poolSize += 26;
    if (password.contains(RegExp(r'[0-9]'))) poolSize += 10;
    if (password.contains(RegExp(r'[^a-zA-Z0-9]'))) poolSize += 33;
    if (poolSize == 0) poolSize = 10;

    // Shannon/NIST Entropy in bits = length * log2(poolSize)
    final entropyBits = password.length * (log(poolSize) / log(2));

    // 2. Score calculation based on length, entropy & character sets
    int score = 0;

    // Checks
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[^a-zA-Z0-9]'));

    final varietyCount = (hasLower ? 1 : 0) +
        (hasUpper ? 1 : 0) +
        (hasDigits ? 1 : 0) +
        (hasSpecial ? 1 : 0);

    // Score based on entropy bits
    if (entropyBits < 28 || password.length < 6) {
      score = 0; // Very Weak
    } else if (entropyBits < 45 || password.length < 9) {
      score = 1; // Weak
    } else if (entropyBits < 65 || varietyCount < 2) {
      score = 2; // Fair
    } else if (entropyBits < 85 || varietyCount < 3) {
      score = 3; // Strong
    } else {
      score = 4; // Very Strong
    }

    // Penalize trivial repeating or sequential patterns
    if (RegExp(r'(.)\1{3,}').hasMatch(password) ||
        password == '123456' ||
        password == 'password' ||
        password == 'admin123') {
      score = (score > 0) ? score - 1 : 0;
    }

    // Label, Color and Crack-Time estimation
    String label;
    Color color;
    String crackTime;
    String recommendation;

    switch (score) {
      case 0:
        label = 'Very Weak';
        color = const Color(0xFFEF4444);
        crackTime = '< 1 second';
        recommendation =
            'Easily cracked by brute-force. Add more characters and symbols.';
        break;
      case 1:
        label = 'Weak';
        color = const Color(0xFFF97316);
        crackTime = 'Few minutes';
        recommendation =
            'Vulnerable to online dictionary attacks. Make it at least 12 characters.';
        break;
      case 2:
        label = 'Fair';
        color = const Color(0xFFFBBF24);
        crackTime = 'Few days / weeks';
        recommendation =
            'Decent, but could be stronger with uppercase letters and special symbols.';
        break;
      case 3:
        label = 'Strong';
        color = const Color(0xFF84CC16);
        crackTime = 'Centuries';
        recommendation =
            'Great password. Resistant to modern offline GPU cracking.';
        break;
      case 4:
      default:
        label = 'Very Strong';
        color = const Color(0xFF10B981);
        crackTime = 'Millions of years';
        recommendation = 'Exceptional cryptographic entropy. Highly secure.';
        break;
    }

    return StrengthResult(
      score: score,
      label: label,
      color: color,
      entropyBits: entropyBits,
      crackTimeEstimate: crackTime,
      recommendation: recommendation,
    );
  }

  /// Legacy helper returning integer 0-4
  static int calculateStrength(String password) {
    return evaluateStrength(password).score;
  }

  static String getStrengthLabel(int strength) {
    switch (strength) {
      case 0:
        return 'Very Weak';
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Strong';
      case 4:
        return 'Very Strong';
      default:
        return 'Unknown';
    }
  }

  static Color getStrengthColor(int strength) {
    switch (strength) {
      case 0:
        return const Color(0xFFEF4444);
      case 1:
        return const Color(0xFFF97316);
      case 2:
        return const Color(0xFFFBBF24);
      case 3:
        return const Color(0xFF84CC16);
      case 4:
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
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
    return base32Encode(bytes)
        .replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ')
        .trim();
  }

  /// Validate TOTP secret format
  static bool isValidTOTPSecret(String secret) {
    final normalized = secret.replaceAll(' ', '').toUpperCase();
    if (normalized.length < 16 || normalized.length > 64) return false;
    return RegExp(r'^[A-Z2-7]+$').hasMatch(normalized);
  }
}
