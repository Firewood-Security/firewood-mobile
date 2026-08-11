// services/app_version_service.dart
// Centralized app versioning metadata for Firewood Android

class AppVersionService {
  static const String version = '1.0.0';
  static const int buildNumber = 1;
  static const String releaseDate = '2026-08-01';
  static const String protocolVersion = 'v1';

  static String get fullVersionString => 'v$version';
  static String get shortVersionString => 'v$version';
  static String get userAgent => 'Firewood-Android/$version ($protocolVersion)';
}
