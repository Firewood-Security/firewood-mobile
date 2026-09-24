@Timeout(Duration(minutes: 5))
// Phase 3 security negatives for backup import (REQ: restore robustness).
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:firewood/database/isar_service.dart';
import 'package:firewood/services/backup_service.dart';
import 'package:firewood/services/item_service.dart';
import 'package:firewood/services/vault_service.dart';
import 'package:firewood/security/crypto_service.dart';
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

  group('BackupService negative paths', () {
    late Directory tempDir;
    late VaultService vaultService;
    late ItemService itemService;
    late BackupService backupService;
    final crypto = CryptoService();

    setUpAll(() async {
      await initIsarForTests();
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_neg_');
      PathProviderPlatform.instance = _MockPaths(tempDir.path);
      vaultService = VaultService();
      itemService = ItemService();
      backupService = BackupService();
    });

    tearDown(() async {
      try {
        await IsarService().close();
      } catch (_) {}
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('rejects truncated files (<40 bytes)', () async {
      final file = File('${tempDir.path}/tiny.firewood');
      await file.writeAsBytes(List<int>.filled(10, 0));
      expect(
        () async => await backupService.importVault(file.path, 'whatever12',
            overwrite: true),
        throwsA(predicate(
            (e) => e.toString().contains('Invalid backup file format'))),
      );
    });

    test('wrong password and corruption share one non-oracle error', () async {
      const password = 'CorrectBackupPass1!';
      await vaultService.createVault(password);
      final key = await vaultService.unlock(password);
      await itemService.addItem(
          key: key, type: 'Login', title: 'a', fields: {'username': 'u'});
      final path = await backupService.exportVault(
          password, '${tempDir.path}/good.firewood');
      expect(
        () async => await backupService.importVault(path, 'WrongPassword9!',
            overwrite: true),
        throwsA(predicate((e) => e
            .toString()
            .contains('Incorrect backup password or corrupted backup file'))),
      );
    });

    test('rejects incompatible backup version strictly', () async {
      const password = 'VersionCheckPass1!';
      final fileSalt = crypto.generateSalt();
      final fileKey = await crypto.deriveKey(password, fileSalt);
      final inner = jsonEncode({
        'version': '9.9.9',
        'vaultId': 'v',
        'vaultName': 'n',
        'salt': crypto.generateSalt(),
        'items': [],
      });
      final enc = await crypto.encrypt(utf8.encode(inner), fileKey);
      final bytes = [...fileSalt, ...enc.nonce, ...enc.ciphertext];
      final fixed = File('${tempDir.path}/badver.firewood');
      await fixed.writeAsBytes(bytes);
      expect(
        () async => await backupService.importVault(fixed.path, password,
            overwrite: true),
        throwsA(predicate(
            (e) => e.toString().contains('Incompatible backup version'))),
      );
    });

    test('merge import preserves existing items and adds backup items',
        () async {
      const backupPassword = 'BackupMergePass1!';
      await vaultService.createVault(backupPassword);
      final backupKey = await vaultService.unlock(backupPassword);
      await itemService.addItem(
          key: backupKey,
          type: 'Login',
          title: 'from-backup',
          fields: {'username': 'b'});
      final path = await backupService.exportVault(
          backupPassword, '${tempDir.path}/m.firewood');

      await vaultService.burnAllVaults();
      try {
        await IsarService().close();
      } catch (_) {}

      const livePassword = 'LiveVaultPass22!!';
      await vaultService.createVault(livePassword);
      final liveKey = await vaultService.unlock(livePassword);
      await itemService.addItem(
          key: liveKey,
          type: 'Note',
          title: 'live-item',
          fields: {'content': 'hi'});

      final name = await backupService.importVault(path, backupPassword,
          overwrite: false, activeVaultKey: liveKey);
      expect(name, isNotEmpty);
      final items = await itemService.getAllItems(liveKey);
      expect(
          items.map((e) => e.title), containsAll(['live-item', 'from-backup']));
    });
  });
}
