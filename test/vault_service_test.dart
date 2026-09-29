import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:firewood/database/isar_service.dart';
import 'package:firewood/database/schemas.dart';
import 'package:firewood/services/vault_service.dart';
import 'package:isar/isar.dart';
import 'isar_test_helper.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  MockPathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getDownloadsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultService Tests', () {
    late Directory tempDir;
    late VaultService vaultService;

    setUpAll(() async {
      await initIsarForTests();
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('firewood_test_');
      PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
      vaultService = VaultService();
    });

    tearDown(() async {
      try {
        await IsarService().close();
      } catch (_) {}
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('hasAnyVault returns false initially', () async {
      expect(await vaultService.hasAnyVault(), isFalse);
    });

    test('createVault and unlock validates password', () async {
      const password = 'SuperMasterPassword123!';

      await vaultService.createVault(password);
      expect(await vaultService.hasAnyVault(), isTrue);

      final key = await vaultService.unlock(password);
      final keyBytes = await key.extractBytes();
      expect(keyBytes.length, equals(32));

      // Wrong password should throw
      expect(
        () async => await vaultService.unlock('WrongPassword123!'),
        throwsA(isA<VaultException>()),
      );
    });

    test('creating a new vault overwrites existing', () async {
      await vaultService.createVault('Password123!');
      expect(await vaultService.hasAnyVault(), isTrue);

      // Creating again overwrites (single-vault behavior)
      await vaultService.createVault('NewPassword456!');
      expect(await vaultService.hasAnyVault(), isTrue);

      // Old password no longer works
      expect(
        () async => await vaultService.unlock('Password123!'),
        throwsA(isA<VaultException>()),
      );
    });

    test('V-035: missing verifier refuses to unlock (no any-password bypass)',
        () async {
      const password = 'SuperMasterPassword123!';
      await vaultService.createVault(password);

      // Simulate a damaged vault record: strip the verifier pair the way
      // corruption/tampering would.
      final isar = await IsarService().instance;
      await isar.writeTxn(() async {
        final vault = await isar.vaults.where().findFirst();
        expect(vault, isNotNull);
        vault!
          ..verifierToken = null
          ..verifierNonce = null;
        await isar.vaults.put(vault);
      });

      // Even with the CORRECT password, unlock must fail hard with the
      // verifier error — never silently succeed or claim a wrong password.
      expect(
        () async => await vaultService.unlock(password),
        throwsA(isA<VaultException>()
            .having((e) => e.message, 'message', contains('verifier missing'))),
      );
    });
  });
}
