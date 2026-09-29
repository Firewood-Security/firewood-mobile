// services/update_service.dart
// Secure Updater Service: TLS-only JSON + Ed25519-signed manifests (V-013),
// allowlisted download URLs, and in-app artifact download with an enforced
// SHA-256 before anything reaches the installer.

import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'app_version_service.dart';
import 'notification_service.dart';
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
  /// Release-class change with review. Responses are TLS-only JSON whose
  /// authenticity comes from the pinned Ed25519 manifest signature (V-013) —
  /// TLS alone makes no authenticated-update claims.
  static const String updateHost = 'https://firewood.aburcloud.com';

  /// V-013: pinned Ed25519 public key for update manifests (base64, raw
  /// 32 bytes). The release pipeline signs the canonical payload with the
  /// matching private key (firewood-release/tool/pipeline/manifest.go,
  /// FIREWOOD_UPDATE_SIGNING_KEY); manifests without a valid signature are
  /// rejected — fail closed, no update offered.
  static const String manifestPublicKeyBase64 =
      'Q0JjsHj2KRGpFVYaz4Wm82MYV5EQiVl3UdBPL5uY+sQ=';

  /// Domain-separation prefix of the signed message (V-013).
  static const String _updatePayloadDomain = 'firewood-update-v1';

  /// Channel for handing a hash-verified APK to the system installer (V-013).
  static const MethodChannel _nativeChannel =
      MethodChannel('com.firewood.vault_security');

  static Future<void> initUpdateChecker() async {
    try {
      final info = await UpdateService().checkAppUpdate();
      hasUpdateAvailable.value = info.hasUpdate;
      if (info.hasUpdate) {
        NotificationAlertService.notifyAppUpdate(version: info.version);
      }
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

        // V-013: only manifests signed with the pinned release key are
        // trusted. Unsigned or forged responses throw and land in the
        // fail-closed fallback below — no update offered, no URL acted on.
        if (!await verifyManifestSignature(json)) {
          throw Exception('Update manifest signature verification failed');
        }

        final latestVersion = json['version'] as String? ?? currentVersion;
        final latestBuild =
            (json['buildNumber'] as num?)?.toInt() ?? currentBuildNumber;
        final notes = json['releaseNotes'] as String? ??
            'Bug fixes and performance improvements.';
        final hash = json['sha256'] as String? ?? '';
        // V-013: https + pinned host only (relative pipeline URLs are
        // resolved against updateHost). A signed manifest we produced always
        // carries an allowlisted URL and a hash; anything else is refused.
        final downloadUri =
            resolveDownloadUri(json['downloadUrl'] as String? ?? '');
        if (downloadUri == null || hash.isEmpty) {
          throw Exception('Update manifest failed the download allowlist');
        }
        final mandatory = json['mandatory'] as bool? ?? false;

        final hasUpdate = latestBuild > currentBuildNumber ||
            _isVersionHigher(latestVersion, currentVersion);
        hasUpdateAvailable.value = hasUpdate;

        return AppUpdateInfo(
          version: latestVersion,
          buildNumber: latestBuild,
          releaseNotes: notes,
          downloadUrl: downloadUri.toString(),
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

  // --- V-013: manifest signing, URL allowlist, in-app download -------------

  /// The exact byte string the release pipeline signs and this service
  /// verifies. MUST stay in lockstep with canonicalUpdatePayload in
  /// firewood-release/tool/pipeline/manifest.go — the fixed vector is pinned
  /// by tests on both sides (update_service_v013_test.dart ↔
  /// TestCanonicalUpdatePayload).
  static String canonicalUpdatePayload({
    required String version,
    required int buildNumber,
    required String downloadUrl,
    required String sha256,
    required bool mandatory,
    required String releaseNotes,
  }) =>
      '$_updatePayloadDomain\n'
      '$version\n'
      '$buildNumber\n'
      '$downloadUrl\n'
      '$sha256\n'
      '$mandatory\n'
      '$releaseNotes';

  /// V-013: verifies the manifest's base64 Ed25519 signature against the
  /// pinned key (or [publicKeyBase64], tests only). Any missing field,
  /// malformed encoding or tampered content fails closed → false.
  static Future<bool> verifyManifestSignature(
    Map<String, dynamic> manifest, {
    String? publicKeyBase64,
  }) async {
    final sigB64 = manifest['signature'];
    if (sigB64 is! String || sigB64.isEmpty) return false;
    try {
      final sig = base64.decode(sigB64);
      final pub = base64.decode(publicKeyBase64 ?? manifestPublicKeyBase64);
      if (sig.length != 64 || pub.length != 32) return false;
      // Wrong field types (e.g. mandatory as string) throw → false below.
      final payload = canonicalUpdatePayload(
        version: manifest['version'] as String? ?? '',
        buildNumber: (manifest['buildNumber'] as num?)?.toInt() ?? -1,
        downloadUrl: manifest['downloadUrl'] as String? ?? '',
        sha256: manifest['sha256'] as String? ?? '',
        mandatory: manifest['mandatory'] as bool? ?? false,
        releaseNotes: manifest['releaseNotes'] as String? ?? '',
      );
      final algorithm = Ed25519();
      final key = SimplePublicKey(pub, type: KeyPairType.ed25519);
      return await algorithm.verify(
        utf8.encode(payload),
        signature: Signature(sig, publicKey: key),
      );
    } catch (_) {
      return false;
    }
  }

  /// V-013: allowlist for update artifact URLs — `https` on the pinned update
  /// host only, no userinfo, no non-default port, no fragment. Relative
  /// references (what the release pipeline publishes) resolve against
  /// [updateHost]; anything else returns null and the download is refused.
  static Uri? resolveDownloadUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    var uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final base = Uri.tryParse(updateHost);
    if (base == null) return null;
    if (!uri.hasScheme) {
      // Relative reference — only absolute-path forms, pinned to our host
      // (network-path references like //evil.example resolve elsewhere and
      // fail the host check below).
      if (!uri.path.startsWith('/')) return null;
      uri = base.resolveUri(uri);
    }
    if (uri.scheme != 'https') return null;
    if (uri.userInfo.isNotEmpty) return null;
    if (uri.host.toLowerCase() != base.host.toLowerCase()) return null;
    if (uri.hasPort && uri.port != 443) return null;
    if (uri.fragment.isNotEmpty) return null;
    return uri;
  }

  /// V-013: downloads the update artifact in-app instead of launching the
  /// manifest's URL externally, then enforces the signed SHA-256 — bytes that
  /// do not match never reach the installer. Redirects are refused so the
  /// connection cannot hop off the allowlisted host mid-download.
  static Future<String> downloadArtifact({
    required Uri uri,
    required String expectedSha256,
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    // Defense in depth: re-run the exact allowlist even though callers pass
    // a URI that already passed it.
    if (resolveDownloadUri(uri.toString()) == null) {
      throw Exception('Update download URL is not allowlisted');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    IOSink? sink;
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false; // V-013: no off-host redirect chains
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw Exception('Update download failed (HTTP ${response.statusCode})');
      }
      final file = File(savePath);
      await file.parent.create(recursive: true);
      sink = file.openWrite();
      var received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, response.contentLength);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (!await verifySha256(savePath, expectedSha256)) {
        try {
          await file.delete();
        } catch (_) {}
        throw Exception('Downloaded update failed SHA-256 verification');
      }
      return savePath;
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client.close(force: true);
    }
  }

  /// V-013: hands the already hash-verified APK to the system installer via
  /// the app's FileProvider (native side re-checks the path is inside the
  /// cache dir it owns).
  static Future<void> installVerifiedApk(String path) async {
    await _nativeChannel.invokeMethod('installUpdate', {'path': path});
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
