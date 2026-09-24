// services/accent_color_service.dart
// Service to manage curated accent color themes across Firewood app with robust persistence

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccentColorOption {
  final String name;
  final Color color;
  final String hex;

  const AccentColorOption({
    required this.name,
    required this.color,
    required this.hex,
  });
}

class AccentColorService {
  static const String _prefKey = 'firewood_accent_color_hex';
  static const String _prefIntKey = 'firewood_accent_color_value';
  static const _secureStorage = FlutterSecureStorage();

  static const AccentColorOption defaultAccent = AccentColorOption(
    name: 'Deep Orange',
    color: Color(0xFFFF5722),
    hex: '#FF5722',
  );

  static const List<AccentColorOption> presets = [
    defaultAccent,
    AccentColorOption(name: 'Emerald Green', color: Color(0xFF10B981), hex: '#10B981'),
    AccentColorOption(name: 'Electric Blue', color: Color(0xFF3B82F6), hex: '#3B82F6'),
    AccentColorOption(name: 'Violet Purple', color: Color(0xFF8B5CF6), hex: '#8B5CF6'),
    AccentColorOption(name: 'Rose Pink', color: Color(0xFFF43F5E), hex: '#F43F5E'),
  ];

  static final ValueNotifier<Color> currentColor = ValueNotifier<Color>(defaultAccent.color);

  /// Initializes accent color from local storage (SharedPreferences with SecureStorage fallback)
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      String? hex = prefs.getString(_prefKey);
      int? colorVal = prefs.getInt(_prefIntKey);

      // Fallback to secure storage if shared_preferences was empty or cleared
      if (hex == null && colorVal == null) {
        try {
          hex = await _secureStorage.read(key: _prefKey);
        } catch (_) {}
      }

      if (colorVal != null) {
        final match = presets.firstWhere(
          (p) => p.color.toARGB32() == colorVal,
          orElse: () => _matchByHex(hex) ?? defaultAccent,
        );
        currentColor.value = match.color;
      } else if (hex != null && hex.isNotEmpty) {
        final match = _matchByHex(hex) ?? defaultAccent;
        currentColor.value = match.color;
      }
    } catch (e) {
      debugPrint('AccentColorService.init error: $e');
    }
  }

  static AccentColorOption? _matchByHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceAll('#', '').trim().toUpperCase();
    try {
      return presets.firstWhere(
        (p) => p.hex.replaceAll('#', '').trim().toUpperCase() == clean,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sets active accent color and persists across app restarts
  static Future<void> setAccentColor(AccentColorOption option) async {
    currentColor.value = option.color;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, option.hex);
      await prefs.setInt(_prefIntKey, option.color.toARGB32());
    } catch (e) {
      debugPrint('Error writing to SharedPreferences: $e');
    }

    try {
      await _secureStorage.write(key: _prefKey, value: option.hex);
    } catch (e) {
      debugPrint('Error writing to SecureStorage: $e');
    }
  }
}
