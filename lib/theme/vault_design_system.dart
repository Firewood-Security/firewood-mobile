// theme/vault_design_system.dart
// Centralized tokens and primitives for the Dark Zinc Technical Vault Design System

import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Standard spacing tokens for consistent visual rhythm
class VaultSpacing {
  VaultSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

/// Standard radius tokens for technical matte surfaces
class VaultRadii {
  VaultRadii._();

  static const double sm = 8.0; // Tags, micro badges
  static const double md = 12.0; // Controls, inputs, chips, tool buttons
  static const double lg = 16.0; // Cards, tiles, category cards
  static const double xl = 20.0; // Hero headers, modals, dialogs
}

/// Standard border styling helpers (1px subtle matte borders)
class VaultBorders {
  VaultBorders._();

  static Border allSubtle({double opacity = 0.5}) => Border.all(
        color: AppColors.borderZinc.withValues(alpha: opacity),
        width: 1.0,
      );

  static Border allAccent(Color accent, {double opacity = 0.3}) => Border.all(
        color: accent.withValues(alpha: opacity),
        width: 1.0,
      );

  static BorderSide subtleBorderSide({double opacity = 0.5}) => BorderSide(
        color: AppColors.borderZinc.withValues(alpha: opacity),
        width: 1.0,
      );
}

/// Standard typography tokens for clear information hierarchy
class VaultTypography {
  VaultTypography._();

  /// Section Label (e.g. "CREDENTIALS", "SECURITY", "TOOLS")
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.1,
    color: AppColors.textMuted,
  );

  /// Primary Dominant Metric (e.g. "42", "94%")
  static TextStyle metricValue(Color accent) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: accent,
        letterSpacing: -0.5,
      );

  /// Card/Tile Title (e.g. "Logins", "GitHub Account")
  static const TextStyle tileTitle = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: AppColors.offWhite,
    letterSpacing: -0.2,
  );

  /// Body Text / Subtitle
  static const TextStyle body = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w400,
  );

  /// Metadata (e.g. "2FA Active", "optimal", timestamps)
  static const TextStyle meta = TextStyle(
    fontSize: 10.5,
    color: AppColors.textMuted,
    fontWeight: FontWeight.w500,
  );
}
