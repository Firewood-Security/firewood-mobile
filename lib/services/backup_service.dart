// services/backup_service.dart
// Encrypted backup/export (.firewood file) and import

import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../database/schemas.dart';
import '../database/isar_service.dart';
import '../security/crypto_service.dart';

class BackupData {
  final String version;
  final DateTime exportedAt;
  final String vaultId;
  final String vaultName;
  final List<int> salt; // Argon2id salt
  final List<BackupItem> items;

  BackupData({
    required this.version,
    required this.exportedAt,
    required this.vaultId,
    required this.vaultName,
    required this.salt,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'exportedAt': exportedAt.toIso8601String(),
    'vaultId': vaultId,
    'vaultName': vaultName,
    'salt': salt,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as String?) ?? '1.0.0';

    final exportedAtStr = (json['exportedAt'] ?? json['exported_at']) as String?;
    final exportedAt = exportedAtStr != null
        ? DateTime.parse(exportedAtStr)
        : DateTime.now().toUtc();

    final vaultObj = json['vault'] as Map<String, dynamic>?;
    final vaultId = (json['vaultId'] ?? vaultObj?['id']) as String? ?? 'default-vault-id';
    final vaultName = (json['vaultName'] ?? vaultObj?['name']) as String? ?? 'Imported Vault';

    final rawSalt = json['salt'] ?? vaultObj?['salt'];
    if (rawSalt == null || rawSalt is! List) {
      throw BackupException('Invalid or missing salt in backup file');
    }
    final salt = List<int>.from(rawSalt);

    final rawItems = json['items'] as List? ?? [];
    final items = rawItems
        .map((e) => BackupItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return BackupData(
      version: version,
      exportedAt: exportedAt,
      vaultId: vaultId,
      vaultName: vaultName,
      salt: salt,
      items: items,
    );
  }
}

class BackupItem {
  final String itemId;
  final String type;
  final String title;
  final List<int> encryptedData;
  final List<int> nonce;
  final DateTime updatedAt;

  BackupItem({
    required this.itemId,
    required this.type,
    required this.title,
    required this.encryptedData,
    required this.nonce,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'type': type,
    'title': title,
    'encryptedData': encryptedData,
    'nonce': nonce,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory BackupItem.fromJson(Map<String, dynamic> json) {
    final itemId = (json['itemId'] ?? json['id']) as String? ?? '';
    final type = (json['type'] ?? json['item_type']) as String? ?? 'login';
    final title = (json['title'] as String?) ?? 'Untitled';

    List<int> encryptedData;
    List<int> nonce;

    if (json.containsKey('encrypted_data') && json['encrypted_data'] is Map) {
      final encMap = json['encrypted_data'] as Map<String, dynamic>;
      encryptedData = List<int>.from((encMap['ciphertext'] as List? ?? []));
      nonce = List<int>.from((encMap['nonce'] as List? ?? []));
    } else {
      encryptedData = List<int>.from((json['encryptedData'] as List? ?? []));
      nonce = List<int>.from((json['nonce'] as List? ?? []));
    }

    final updatedAtStr = json['updatedAt'] ?? json['updated_at'];
    final updatedAt = updatedAtStr != null
        ? DateTime.parse(updatedAtStr as String)
        : DateTime.now().toUtc();

    return BackupItem(
      itemId: itemId,
      type: type,
      title: title,
      encryptedData: encryptedData,
      nonce: nonce,
      updatedAt: updatedAt,
    );
  }
}

class BackupService {
  static const String _fileExtension = '.firewood';
  static const String _version = '1.0.0';

  final IsarService _isarService = IsarService();
  final CryptoService _crypto = CryptoService();

  /// Export vault to encrypted .firewood file
  /// The file is encrypted with a key derived from the master password
  Future<String> exportVault(
    String masterPassword,
    String? customPath,
  ) async {
    final isar = await _isarService.instance;

    // Get vault info
    var vault = await isar.vaults.where().findFirst();
    if (vault == null) {
      final salt = _crypto.generateSalt();
      final key = await _crypto.deriveKey(masterPassword, salt);
      final verifier = await _crypto.encryptString('FIREWOOD_VAULT_VERIFY', key);

      vault = Vault()
        ..vaultId = const Uuid().v4()
        ..name = 'Primary Vault'
        ..salt = salt
        ..verifierToken = verifier.ciphertext
        ..verifierNonce = verifier.nonce
        ..isDefault = true
        ..createdAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.vaults.put(vault!);
      });
    }

    // Verify master password against existing vault first
    final SecretKey exportKey;
    try {
      exportKey = await _crypto.deriveKey(masterPassword, vault.salt);
      if (vault.verifierToken != null && vault.verifierNonce != null) {
        final verifyStr = await _crypto.decryptString(
          vault.verifierToken!,
          vault.verifierNonce!,
          exportKey,
        );
        if (verifyStr != 'FIREWOOD_VAULT_VERIFY') {
          throw BackupException('Incorrect master password');
        }
      }
    } catch (e) {
      if (e is BackupException) rethrow;
      throw BackupException('Incorrect master password');
    }

    // Get all items
    final items = await isar.secureItems.where().findAll();

    // Convert to backup items (re-encrypt with export key)
    final backupItems = <BackupItem>[];
    for (final item in items) {
      // Decrypt with vault key
      final plaintext = await _crypto.decrypt(item.encryptedData, item.nonce, exportKey);
      
      // Re-encrypt with export key (fresh nonce)
      final encrypted = await _crypto.encrypt(plaintext, exportKey);
      
      backupItems.add(BackupItem(
        itemId: item.itemId,
        type: item.type,
        title: item.title,
        encryptedData: encrypted.ciphertext,
        nonce: encrypted.nonce,
        updatedAt: item.updatedAt,
      ));
    }

    // Create backup data
    final backupData = BackupData(
      version: _version,
      exportedAt: DateTime.now().toUtc(),
      vaultId: vault.vaultId,
      vaultName: vault.name,
      salt: vault.salt,
      items: backupItems,
    );

    // Serialize to JSON
    final jsonString = jsonEncode(backupData.toJson());
    final jsonBytes = utf8.encode(jsonString);

    // Encrypt the entire backup with a file-level key
    // Derive file encryption key from master password + export-specific salt
    final fileSalt = _crypto.generateSalt();
    final fileKey = await _crypto.deriveKey(masterPassword, fileSalt);
    final fileEncrypted = await _crypto.encrypt(jsonBytes, fileKey);

    // Combine: fileSalt || nonce || ciphertext
    final output = <int>[];
    output.addAll(fileSalt);
    output.addAll(fileEncrypted.nonce);
    output.addAll(fileEncrypted.ciphertext);

    // Determine file path
    String filePath;
    if (customPath != null) {
      filePath = customPath;
      if (!filePath.endsWith(_fileExtension)) {
        filePath += _fileExtension;
      }
    } else {
      final dir = await _getExportDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      filePath = '${dir.path}/firewood-backup-$timestamp$_fileExtension';
    }

    // Write file
    final file = File(filePath);
    await file.writeAsBytes(output, flush: true);

    return filePath;
  }

  /// Helper to locate Downloads directory (/storage/emulated/0/Download/Firewood)
  Future<Directory> _getExportDirectory() async {
    try {
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download/Firewood');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir;
      } else if (!Platform.isIOS) {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          final firewoodDir = Directory('${downloads.path}/Firewood');
          if (!await firewoodDir.exists()) {
            await firewoodDir.create(recursive: true);
          }
          return firewoodDir;
        }
      }
    } catch (_) {}
    return await getApplicationDocumentsDirectory();
  }

  /// Import vault from .firewood file
  /// If [overwrite] is true, replaces the entire vault.
  /// If [overwrite] is false and vault exists, merges items into current vault using [activeVaultKey].
  Future<String> importVault(
    String filePath,
    String masterPassword, {
    bool overwrite = false,
    SecretKey? activeVaultKey,
  }) async {
    final isar = await _isarService.instance;

    // Read file
    final file = File(filePath);
    if (!await file.exists()) {
      throw BackupException('Backup file not found');
    }

    final fileBytes = await file.readAsBytes();

    // Parse: fileSalt (16) || nonce (24) || ciphertext
    if (fileBytes.length < 40) {
      throw BackupException('Invalid backup file format');
    }

    final fileSalt = fileBytes.sublist(0, 16);
    final nonce = fileBytes.sublist(16, 40);
    final ciphertext = fileBytes.sublist(40);

    // Derive file key and decrypt
    final fileKey = await _crypto.deriveKey(masterPassword, fileSalt);
    final List<int> jsonBytes;
    try {
      jsonBytes = await _crypto.decrypt(ciphertext, nonce, fileKey);
    } catch (_) {
      throw BackupException('Incorrect backup password or corrupted backup file.');
    }
    final jsonString = utf8.decode(jsonBytes);

    // Parse backup data
    final BackupData backupData;
    try {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      backupData = BackupData.fromJson(jsonMap);
    } catch (e) {
      if (e is BackupException) rethrow;
      throw BackupException('Corrupted backup file content: $e');
    }

    // Verify version compatibility
    if (backupData.version != _version) {
      throw BackupException(
        'Incompatible backup version: ${backupData.version} (expected $_version)',
      );
    }

    // Derive export key for backup items from masterPassword + backupData.salt
    final backupItemKey = await _crypto.deriveKey(masterPassword, backupData.salt);

    final existingVault = await isar.vaults.where().findFirst();

    if (existingVault != null && !overwrite && activeVaultKey != null) {
      // MERGE MODE: Re-encrypt backup items with current active vault key and add to vault
      for (final backupItem in backupData.items) {
        // Decrypt plaintext from backup using backup key
        final plaintext = await _crypto.decrypt(
          backupItem.encryptedData,
          backupItem.nonce,
          backupItemKey,
        );

        // Re-encrypt with active vault key
        final reEncrypted = await _crypto.encrypt(plaintext, activeVaultKey);

        final item = SecureItem()
          ..itemId = backupItem.itemId
          ..vaultId = backupData.vaultId
          ..encryptedData = reEncrypted.ciphertext
          ..nonce = reEncrypted.nonce
          ..type = backupItem.type
          ..title = backupItem.title
          ..updatedAt = backupItem.updatedAt;

        await isar.writeTxn(() async {
          await isar.secureItems.put(item);
        });
      }
      return '${backupData.vaultName} (${backupData.items.length} items merged)';
    } else {
      // FULL RESTORE MODE: Replace or initialize vault
      if (overwrite) {
        await isar.writeTxn(() async {
          await isar.vaults.where().deleteAll();
          await isar.secureItems.where().deleteAll();
        });
      }

      // Generate verification token for the new master password
      final verifier = await _crypto.encryptString('FIREWOOD_VAULT_VERIFY', backupItemKey);

      final vault = Vault()
        ..vaultId = backupData.vaultId
        ..name = backupData.vaultName
        ..salt = backupData.salt
        ..verifierToken = verifier.ciphertext
        ..verifierNonce = verifier.nonce
        ..createdAt = backupData.exportedAt
        ..isDefault = true;

      await isar.writeTxn(() async {
        await isar.vaults.put(vault);
      });

      // Import items
      for (final backupItem in backupData.items) {
        final plaintext = await _crypto.decrypt(
          backupItem.encryptedData,
          backupItem.nonce,
          backupItemKey,
        );

        final encrypted = await _crypto.encrypt(plaintext, backupItemKey);

        final item = SecureItem()
          ..itemId = backupItem.itemId
          ..vaultId = backupData.vaultId
          ..encryptedData = encrypted.ciphertext
          ..nonce = encrypted.nonce
          ..type = backupItem.type
          ..title = backupItem.title
          ..updatedAt = backupItem.updatedAt;

        await isar.writeTxn(() async {
          await isar.secureItems.put(item);
        });
      }

      return backupData.vaultName;
    }
  }
}

class BackupException implements Exception {
  final String message;
  BackupException(this.message);
  @override
  String toString() => 'BackupException: $message';
}