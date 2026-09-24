@Timeout(Duration(minutes: 5))
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:firewood/database/isar_service.dart';
import 'package:firewood/services/vault_service.dart';
import 'package:firewood/services/item_service.dart';
import 'package:firewood/services/backup_service.dart';
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

  group('BackupService Export and Import Roundtrip Tests', () {
    late Directory tempDir;
    late VaultService vaultService;
    late ItemService itemService;
    late BackupService backupService;

    setUpAll(() async {
      await initIsarForTests();
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_test_');
      PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
      vaultService = VaultService();
      itemService = ItemService();
      backupService = BackupService();
    });

    tearDown(() async {
      try {
        await IsarService().close();
      } catch (_) {}
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('export and import vault backup roundtrip', () async {
      const password = 'MySecureMasterPassword123!';

      // 1. Create vault
      await vaultService.createVault(password);
      final key = await vaultService.unlock(password);

      // 2. Add an item
      await itemService.addItem(
        key: key,
        type: 'login',
        title: 'Test Service',
        fields: {'username': 'alice', 'password': 'secret_password_123'},
      );

      // 3. Export vault
      final exportPath = '${tempDir.path}/test_backup.firewood';
      final generatedPath =
          await backupService.exportVault(password, exportPath);
      expect(File(generatedPath).existsSync(), isTrue);

      // 4. Wipe vault
      await vaultService.burnAllVaults();
      expect(await vaultService.hasAnyVault(), isFalse);

      // 5. Import vault with correct password
      final importedVaultName = await backupService.importVault(
        generatedPath,
        password,
        overwrite: true,
      );
      expect(importedVaultName, isNotEmpty);

      // 6. Verify unlocked vault contains item
      final restoredKey = await vaultService.unlock(password);
      final items = await itemService.getAllItems(restoredKey);

      expect(items.length, equals(1));
      expect(items.first.title, equals('Test Service'));
      expect(items.first.fields['username'], equals('alice'));
      expect(items.first.fields['password'], equals('secret_password_123'));
    });

    test('BackupData.fromJson deserializes both Dart and Rust format JSON', () {
      final rustJson = {
        'version': '1.0.0',
        'exported_at': '2026-07-31T00:00:00.000Z',
        'vault': {
          'id': 'rust-vault-123',
          'name': 'Rust Vault',
          'salt': [1, 2, 3, 4],
          'created_at': '2026-07-31T00:00:00.000Z',
        },
        'items': [
          {
            'id': 'item-1',
            'item_type': 'login',
            'title': 'Rust Item',
            'encrypted_data': {
              'ciphertext': [10, 20, 30],
              'nonce': [1, 2, 3],
            },
            'updated_at': '2026-07-31T00:00:00.000Z',
          }
        ]
      };

      final backupData = BackupData.fromJson(rustJson);
      expect(backupData.vaultId, equals('rust-vault-123'));
      expect(backupData.vaultName, equals('Rust Vault'));
      expect(backupData.salt, equals([1, 2, 3, 4]));
      expect(backupData.items.length, equals(1));
      expect(backupData.items.first.itemId, equals('item-1'));
      expect(backupData.items.first.title, equals('Rust Item'));
      expect(backupData.items.first.encryptedData, equals([10, 20, 30]));
      expect(backupData.items.first.nonce, equals([1, 2, 3]));
    });
  });
}
