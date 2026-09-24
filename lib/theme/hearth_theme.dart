// theme/hearth_theme.dart
// Desktop-only "hearth" visual language: warm coal surfaces, ember accents and
// soft glows that give the desktop workspace a distinct identity while leaving
// the mobile app on the existing zinc/orange palette.

import 'package:flutter/material.dart';

class HearthColors {
  HearthColors._();

  // Coal / hearth surfaces (warm dark, not neutral zinc)
  static const Color coal = Color(0xFF0B0908);
  static const Color coalSoft = Color(0xFF12100E);
  static const Color hearth = Color(0xFF1A1512);
  static const Color hearthRaised = Color(0xFF241C17);
  static const Color hearthEdge = Color(0xFF3A2C23);

  // Ember accents
  static const Color ember = Color(0xFFFF6B35);
  static const Color emberBright = Color(0xFFFF9163);
  static const Color emberDeep = Color(0xFFB23A18);
  static const Color emberGlow = Color(0x40FF6B35);

  // Ink / ash text
  static const Color ash = Color(0xFFF5EFE9);
  static const Color ashMuted = Color(0xFFA79A90);
  static const Color ashFaint = Color(0xFF6E625A);

  // Status
  static const Color good = Color(0xFF4ADE80);
  static const Color warn = Color(0xFFFBBF24);
  static const Color bad = Color(0xFFF87171);

  static const LinearGradient hearthGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1C1512), Color(0xFF0B0908)],
  );

  static const LinearGradient emberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emberBright, ember, emberDeep],
  );

  /// Soft ember halo used behind the active nav item / focused panes.
  static List<BoxShadow> emberHalo({double blur = 24, double alpha = 0.35}) => [
        BoxShadow(
          color: ember.withValues(alpha: alpha),
          blurRadius: blur,
          spreadRadius: 1,
        ),
      ];

  /// Raised panel decoration used by panes and cards on desktop.
  static BoxDecoration panel({bool raised = false, bool highlight = false}) {
    return BoxDecoration(
      color: raised ? hearthRaised : hearth,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: highlight ? ember.withValues(alpha: 0.45) : hearthEdge,
      ),
    );
  }
}
