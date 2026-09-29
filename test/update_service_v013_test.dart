// V-013: update channel hardening — Ed25519 manifest signature against the
// pinned key, tamper rejection, the https+host download allowlist, and the
// SHA-256 verifier that the in-app download now actually enforces.
//
// The canonical-payload vector and the signed fixture are shared with the
// release pipeline (firewood-release/tool/pipeline/manifest_test.go) so the
// Go signer and this verifier cannot drift apart silently.

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firewood/services/update_service.dart';

void main() {
  // Must equal TestCanonicalUpdatePayload in manifest_test.go.
  const expectedCanonical = 'firewood-update-v1\n'
      '1.0.0\n'
      '42\n'
      '/downloads/firewood-latest-android.apk\n'
      'fbc34a9a500e23329b18ccefe171001584589546b2eee4d380b53e2068b68255\n'
      'false\n'
      '• security fixes';

  Map<String, dynamic> fixedManifest() => <String, dynamic>{
        'version': '1.0.0',
        'buildNumber': 42,
        'releaseNotes': '• security fixes',
        'downloadUrl': '/downloads/firewood-latest-android.apk',
        'sha256':
            'fbc34a9a500e23329b18ccefe171001584589546b2eee4d380b53e2068b68255',
        'mandatory': false,
        'publishedAt': '2026-09-27T00:00:00Z',
        'commit': '0000000',
      };

  group('V-013 canonical payload', () {
    test('matches the cross-language fixed vector', () {
      final m = fixedManifest();
      expect(
        UpdateService.canonicalUpdatePayload(
          version: m['version'] as String,
          buildNumber: m['buildNumber'] as int,
          downloadUrl: m['downloadUrl'] as String,
          sha256: m['sha256'] as String,
          mandatory: m['mandatory'] as bool,
          releaseNotes: m['releaseNotes'] as String,
        ),
        expectedCanonical,
      );
    });

    test('pinned public key is a well-formed raw Ed25519 key', () {
      expect(base64.decode(UpdateService.manifestPublicKeyBase64).length, 32);
    });
  });

  group('V-013 manifest signature', () {
    test('fixture signed by the real pipeline key verifies against the pin',
        () async {
      final file = File('test/fixtures/signed_update_manifest.json');
      expect(await file.exists(), isTrue,
          reason: 'pipeline fixture missing — regenerate with '
              'TestWriteSignedUpdateManifestFixture');
      final manifest =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(await UpdateService.verifyManifestSignature(manifest), isTrue,
          reason: 'pinned key must verify the Go-signed fixture');
    });

    test('tampered downloadUrl fails (forged redirect target)', () async {
      final file = File('test/fixtures/signed_update_manifest.json');
      final manifest =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      manifest['downloadUrl'] = 'https://evil.example/pwn.apk';
      expect(await UpdateService.verifyManifestSignature(manifest), isFalse);
    });

    test('tampered sha256 fails (forged artifact hash)', () async {
      final file = File('test/fixtures/signed_update_manifest.json');
      final manifest =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      manifest['sha256'] = '0' * 64;
      expect(await UpdateService.verifyManifestSignature(manifest), isFalse);
    });

    test('missing or malformed signature fails closed', () async {
      final m = fixedManifest();
      expect(await UpdateService.verifyManifestSignature(m), isFalse,
          reason: 'no signature field');
      m['signature'] = 'not-base64!!!';
      expect(await UpdateService.verifyManifestSignature(m), isFalse,
          reason: 'malformed signature');
      m['signature'] = base64.encode(List<int>.filled(64, 7));
      expect(await UpdateService.verifyManifestSignature(m), isFalse,
          reason: 'well-formed but wrong signature');
    });

    test('signature over the wrong key does not verify', () async {
      final keyPair = await Ed25519().newKeyPair();
      final pub = await keyPair.extractPublicKey();
      final sig = await Ed25519().sign(
        utf8.encode(expectedCanonical),
        keyPair: keyPair,
      );
      final m = fixedManifest()..['signature'] = base64.encode(sig.bytes);
      // Right shape, right payload — but not the pinned key.
      expect(
        await UpdateService.verifyManifestSignature(
          m,
          publicKeyBase64: base64.encode(pub.bytes),
        ),
        isTrue,
        reason: 'sanity: test-key signature verifies under the test key',
      );
      expect(await UpdateService.verifyManifestSignature(m), isFalse,
          reason: 'pinned key must reject it');
    });
  });

  group('V-013 download URL allowlist', () {
    void accept(String raw) =>
        expect(UpdateService.resolveDownloadUri(raw), isNotNull,
            reason: '$raw should be allowed');
    void reject(String raw) =>
        expect(UpdateService.resolveDownloadUri(raw), isNull,
            reason: '$raw should be refused');

    test('accepts https on the pinned host and relative pipeline URLs', () {
      accept('https://firewood.aburcloud.com/downloads/x.apk');
      accept('https://Firewood.aburcloud.com/downloads/x.apk');
      accept('https://firewood.aburcloud.com:443/downloads/x.apk');
      accept('/downloads/firewood-latest-android.apk');
    });

    test('rejects every other scheme, host, port or trick', () {
      reject('');
      reject('http://firewood.aburcloud.com/downloads/x.apk');
      reject('https://evil.example/x.apk');
      reject('https://firewood.aburcloud.com.evil.example/x.apk');
      reject('https://evil.example@firewood.aburcloud.com/x.apk');
      reject('https://firewood.aburcloud.com@evil.example/x.apk');
      reject('https://firewood.aburcloud.com:8443/x.apk');
      reject('https://firewood.aburcloud.com/x.apk#frag');
      reject('//evil.example/x.apk');
      reject('downloads/x.apk');
      reject('javascript:alert(1)');
      reject('market://details?id=evil');
    });
  });

  group('V-013 verifySha256 (now enforced by downloadArtifact)', () {
    test('passes only on exact match; empty/missing expectation fails',
        () async {
      final dir = Directory.systemTemp.createTempSync('v013_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/artifact.bin')..writeAsBytesSync([1, 2, 3]);
      // sha256([1,2,3])
      const good =
          '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81';
      expect(await UpdateService.verifySha256(f.path, good), isTrue);
      expect(await UpdateService.verifySha256(f.path, '0' * 64), isFalse);
      expect(await UpdateService.verifySha256(f.path, ''), isFalse);
      expect(await UpdateService.verifySha256('${dir.path}/missing', good),
          isFalse);
    });
  });
}
