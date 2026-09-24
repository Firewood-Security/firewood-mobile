// services/app_version_service.dart
// Centralized app versioning for Firewood Android.
//
// The installed package (Android versionName/versionCode, i.e. the pubspec
// `version:` field) is the single source of truth: values are read at runtime
// via PackageInfo, so every surface (login footer, settings, update checks)
// follows whatever build is actually deployed. The constants below are only
// fallbacks used before init() completes or if the platform channel fails.

import 'package:package_info_plus/package_info_plus.dart';

class AppVersionService {
  // Fallback only — keep in sync with pubspec `version:`.
  static const String _fallbackVersion = '1.0.0';
  static const int _fallbackBuildNumber = 1;

  static String? _version;
  static int? _buildNumber;

  static const String releaseDate = '2026-08-01';
  static const String protocolVersion = 'v1';

  /// Loads the real deployed version. Call once during app startup.
  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _buildNumber =
          int.tryParse(info.buildNumber) ?? _fallbackBuildNumber;
    } catch (_) {
      // Keep fallbacks if the platform channel is unavailable.
    }
  }

  static String get version => _version ?? _fallbackVersion;
  static int get buildNumber => _buildNumber ?? _fallbackBuildNumber;

  static String get fullVersionString => 'v$version';
  static String get shortVersionString => 'v$version';
  static String get userAgent => 'Firewood-Android/$version ($protocolVersion)';
}
