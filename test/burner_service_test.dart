@Timeout(Duration(minutes: 5))
// Phase 3 burner tests (ADR-006): policy minimum, per-entry salts,
// legacy static-salt fallback for migration rows.
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:firewood/database/isar_service.dart';
import 'package:firewood/database/schemas.dart';
import 'package:firewood/services/burner_service.dart';
import 'isar_test_helper.dart';

class _MockPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String path;
  _MockPaths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getDownloadsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BurnerService (ADR-006)', () {
    late Directory tempDir;
    late BurnerService burnerService;

    setUpAll(() async {
      await initIsarForTests();
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('burner_test_');
      PathProviderPlatform.instance = _MockPaths(tempDir.path);
      burnerService = BurnerService();
    });

    tearDown(() async {
      try {
        await IsarService().close();
      } catch (_) {}
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('rejects burner passwords shorter than 8 chars', () async {
      expect(
        () async => await burnerService.addBurnerPassword('short1'),
        throwsA(isA<BurnerException>()),
      );
    });

    test('roundtrip: added burner matches, wrong password does not', () async {
      expect(await burnerService.isBurnerPassword('DuressCode99!'), isFalse);
      await burnerService.addBurnerPassword('DuressCode99!');
      expect(await burnerService.isBurnerPassword('DuressCode99!'), isTrue);
      expect(await burnerService.isBurnerPassword('DuressCode98!'), isFalse);
    });

    test('new entries carry distinct per-entry salts', () async {
      await burnerService.addBurnerPassword('FirstBurner!!');
      await burnerService.addBurnerPassword('SecondBurner!');
      final rows = await burnerService.listBurners();
      expect(rows.length, equals(2));
      for (final r in rows) {
        expect(r.salt, isNotNull);
        expect(r.salt, hasLength(16));
      }
      expect(rows[0].salt, isNot(equals(rows[1].salt)));
    });

    test('legacy salt-less rows still verify via static fallback', () async {
      const password = 'LegacyBurner12';
      final argon2 =
          Argon2id(memory: 65536, iterations: 3, parallelism: 4, hashLength: 32);
      final hash = await argon2.deriveKeyFromPassword(
          password: password, nonce: BurnerService.legacyStaticSalt);
      final isar = await IsarService().instance;
      await isar.writeTxn(() async {
        await isar.burnerHashs.put(BurnerHash()
          ..passwordHash = base64Encode(await hash.extractBytes())
          ..label = 'legacy'
          ..createdAt = DateTime.now());
      });
      expect(await burnerService.isBurnerPassword(password), isTrue);
      expect(await burnerService.isBurnerPassword('SomethingElse99'), isFalse);
    });
  });
}
