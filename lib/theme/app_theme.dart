// theme/app_theme.dart
// Minimal matte design system: flat fills, thin 1px borders, no gradients,
// no glows, no shadows. Accent highlights are flat color only.

import 'package:flutter/material.dart';

import '../services/accent_color_service.dart';

class AppColors {
  // Dark Zinc Base
  static const backgroundZinc = Color(0xFF09090B); // Deep Dark Zinc
  static const surfaceZinc = Color(0xFF18181B);    // Surface Zinc
  static const cardZinc = Color(0xFF242427);       // Card Zinc
  static const borderZinc = Color(0xFF3F3F46);     // Border Zinc
  static const inputZinc = Color(0xFF141416);      // Input Fill

  // Text palette
  static const offWhite = Color(0xFFFAFAFA);       // Pure Soft White
  static const textSecondary = Color(0xFFE4E4E7);  // Light Gray
  static const textMuted = Color(0xFFA1A1AA);      // Slate Gray

  // --- Dynamic Accent Palette (Synced with AccentColorService) ---
  static Color get orangeAccent => AccentColorService.currentColor.value;
  static Color get orangeBright {
    final hsl = HSLColor.fromColor(orangeAccent);
    return hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
  }
  static Color get orangeDark {
    final hsl = HSLColor.fromColor(orangeAccent);
    return hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
  }
  static Color get orangeContainer {
    final hsl = HSLColor.fromColor(orangeAccent);
    return hsl.withLightness(0.14).withSaturation(0.65).toColor();
  }
  static Color get orangeBorder {
    final hsl = HSLColor.fromColor(orangeAccent);
    return hsl.withLightness(0.26).withSaturation(0.55).toColor();
  }
  static Color get orangeOnContainer {
    final hsl = HSLColor.fromColor(orangeAccent);
    return hsl.withLightness(0.85).toColor();
  }

  // Functional Accents
  static const roseAccent = Color(0xFFEF4444);     // Danger
  static const roseContainer = Color(0xFF2E1517);
  static const roseBorder = Color(0xFF5A2529);
  static const roseOnContainer = Color(0xFFFECDD3);

  static const mintAccent = Color(0xFF22C55E);     // Success
  static const mintContainer = Color(0xFF132A1C);
  static const mintBorder = Color(0xFF235432);
  static const mintOnContainer = Color(0xFFDCFCE7);

  static const periwinkleAccent = Color(0xFF818CF8); // Info
  static const periwinkleContainer = Color(0xFF1B1D33);
  static const periwinkleBorder = Color(0xFF333866);
  static const periwinkleOnContainer = Color(0xFFE0E7FF);

  // Backward compatibility aliases
  static Color get pastelOrange => orangeAccent;
  static Color get pastelOrangeLight => orangeBright;
  static Color get pastelOrangeContainer => orangeContainer;
  static Color get pastelOrangeBorder => orangeBorder;
  static Color get pastelOrangeOnContainer => orangeOnContainer;

  static const pastelRose = roseAccent;
  static const pastelRoseContainer = roseContainer;
  static const pastelRoseBorder = roseBorder;
  static const pastelRoseOnContainer = roseOnContainer;

  static const pastelMint = mintAccent;
  static const pastelMintContainer = mintContainer;
  static const pastelMintBorder = mintBorder;
  static const pastelMintOnContainer = mintOnContainer;

  static const pastelPeriwinkle = periwinkleAccent;
  static const pastelPeriwinkleContainer = periwinkleContainer;
  static const pastelPeriwinkleBorder = periwinkleBorder;
  static const pastelPeriwinkleOnContainer = periwinkleOnContainer;
}

class AppTheme {
  static ThemeData get darkTheme => getDarkTheme(AppColors.orangeAccent);

  static ThemeData getDarkTheme([Color? accent]) {
    final accentColor = accent ?? AppColors.orangeAccent;
    // Dynamically compute complementary container, border, and contrast colors from accentColor
    final HSLColor hsl = HSLColor.fromColor(accentColor);
    final Color primaryContainer = hsl.withLightness(0.14).withSaturation(0.65).toColor();
    final Color primaryOnContainer = hsl.withLightness(0.85).toColor();
    final Color primaryBorder = hsl.withLightness(0.26).withSaturation(0.55).toColor();
    
    // Complementary secondary palette (180deg hue shift)
    final Color secondaryColor = HSLColor.fromColor(accentColor)
        .withHue((hsl.hue + 180) % 360)
        .withSaturation(0.45)
        .withLightness(0.65)
        .toColor();
    final Color secondaryContainer = HSLColor.fromColor(secondaryColor)
        .withLightness(0.14)
        .toColor();
    final Color secondaryOnContainer = HSLColor.fromColor(secondaryColor)
        .withLightness(0.85)
        .toColor();

    final bool isLightAccent = hsl.lightness > 0.65;
    final Color onPrimaryText = isLightAccent ? const Color(0xFF140C08) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundZinc,
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        onPrimary: onPrimaryText,
        primaryContainer: primaryContainer,
        onPrimaryContainer: primaryOnContainer,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: secondaryOnContainer,
        error: AppColors.roseAccent,
        onError: Colors.white,
        errorContainer: AppColors.roseContainer,
        onErrorContainer: AppColors.roseOnContainer,
        surface: AppColors.surfaceZinc,
        onSurface: AppColors.offWhite,
        onSurfaceVariant: AppColors.textMuted,
        surfaceContainerHighest: AppColors.cardZinc,
        outline: AppColors.borderZinc,
        outlineVariant: primaryBorder,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceZinc,
        foregroundColor: AppColors.offWhite,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardZinc,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderZinc, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: AppColors.inputZinc,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderZinc),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderZinc),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.roseAccent),
        ),
      ),

      // --- Matte Flat Button Themes (no elevation, no glow) ---
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceZinc,
          foregroundColor: AppColors.offWhite,
          side: const BorderSide(color: AppColors.borderZinc, width: 1),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: primaryOnContainer,
          elevation: 0,
          side: BorderSide(color: primaryBorder, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceZinc,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderZinc),
        ),
      ),
    );
  }

  static ThemeData get lightTheme => darkTheme;
}

