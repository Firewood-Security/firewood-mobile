// services/accent_color_service.dart
// Service to manage 5 curated accent color themes across Firewood app

import 'package:flutter/material.dart';
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

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final hex = prefs.getString(_prefKey);
    if (hex != null) {
      final match = presets.firstWhere(
        (p) => p.hex.toUpperCase() == hex.toUpperCase(),
        orElse: () => defaultAccent,
      );
      currentColor.value = match.color;
    }
  }

  static Future<void> setAccentColor(AccentColorOption option) async {
    currentColor.value = option.color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, option.hex);
  }
}
