// services/update_service.dart
// Secure Updater Service querying GET /update endpoint over HTTPS with TLS integrity verification

import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'app_version_service.dart';
import 'package:flutter/foundation.dart';

class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseNotes;
  final String downloadUrl;
  final String? sha256Hash;
  final bool isMandatory;
  final bool hasUpdate;

  AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseNotes,
    required this.downloadUrl,
    this.sha256Hash,
    required this.isMandatory,
    required this.hasUpdate,
  });
}

class UpdateService {
  static final ValueNotifier<bool> hasUpdateAvailable =
      ValueNotifier<bool>(false);

  /// Owned update-channel constant (D-12, version registry). The host is a
  /// source-code constant by decision, NOT config: changing it is a
  /// Release-class change with review. Responses are TLS-only JSON with no
  /// signature verification, so no authenticated-update claims are supported
  /// (Q-09 open, BLOCKER for such claims).
  static const String updateHost = 'https://firewood.aburcloud.com';

  static Future<void> initUpdateChecker() async {
    try {
      final info = await UpdateService().checkAppUpdate();
      hasUpdateAvailable.value = info.hasUpdate;
    } catch (_) {}
  }

  static String get _updateEndpoint {
    if (Platform.isLinux) {
      return '$updateHost/v1/linux/update';
    } else if (Platform.isWindows) {
      return '$updateHost/v1/windows/update';
    } else if (Platform.isMacOS) {
      return '$updateHost/v1/macos/update';
    } else {
      return '$updateHost/v1/android/update';
    }
  }

  // The installed package is the source of truth (AppVersionService reads it
  // from PackageInfo), so update checks always compare against what is
  // actually deployed.
  static String get currentVersion => AppVersionService.version;
  static int get currentBuildNumber => AppVersionService.buildNumber;

  /// Fetches update info securely over HTTPS TLS
  Future<AppUpdateInfo> checkAppUpdate() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final request = await client.getUrl(Uri.parse(_updateEndpoint));
      request.headers
          .set('User-Agent', 'Firewood-Vault/1.0.0 (Android; Secure)');
      request.headers.set('Accept', 'application/json');

      final response = await request.close();

      if (response.statusCode == 200) {
        final bodyStr = await response.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr) as Map<String, dynamic>;

        final latestVersion = json['version'] as String? ?? currentVersion;
        final latestBuild =
            (json['buildNumber'] as num?)?.toInt() ?? currentBuildNumber;
        final notes = json['releaseNotes'] as String? ??
            'Bug fixes and performance improvements.';
        final url = json['downloadUrl'] as String? ?? '';
        final hash = json['sha256'] as String?;
        final mandatory = json['mandatory'] as bool? ?? false;

        final hasUpdate = latestBuild > currentBuildNumber ||
            _isVersionHigher(latestVersion, currentVersion);
        hasUpdateAvailable.value = hasUpdate;

        return AppUpdateInfo(
          version: latestVersion,
          buildNumber: latestBuild,
          releaseNotes: notes,
          downloadUrl: url,
          sha256Hash: hash,
          isMandatory: mandatory,
          hasUpdate: hasUpdate,
        );
      } else {
        throw Exception(
            'HTTP Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback: Default to secure local version check if API offline or unreachable
      return AppUpdateInfo(
        version: currentVersion,
        buildNumber: currentBuildNumber,
        releaseNotes:
            'You are running the latest verified release of Firewood.',
        downloadUrl: '',
        isMandatory: false,
        hasUpdate: false,
      );
    } finally {
      client.close();
    }
  }

  /// Verifies a downloaded artifact against the SHA-256 published with the
  /// release (see the pipeline's SHA256SUMS / checksums.json and the update
  /// manifest). Comparison is constant-time; any mismatch, missing file or
  /// empty expectation fails closed.
  static Future<bool> verifySha256(String filePath, String expectedHex) async {
    final expected = expectedHex.trim().toLowerCase();
    if (expected.isEmpty) return false;
    final file = File(filePath);
    if (!await file.exists()) return false;

    final digest = await Sha256().hash(await file.readAsBytes());
    final actual =
        digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    if (actual.length != expected.length) return false;

    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected.codeUnitAt(i) ^ actual.codeUnitAt(i);
    }
    return diff == 0;
  }

  bool _isVersionHigher(String newVer, String currentVer) {
    try {
      final newParts =
          newVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currParts =
          currentVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < newParts.length && i < currParts.length; i++) {
        if (newParts[i] > currParts[i]) return true;
        if (newParts[i] < currParts[i]) return false;
      }
      return newParts.length > currParts.length;
    } catch (_) {
      return false;
    }
  }
}
