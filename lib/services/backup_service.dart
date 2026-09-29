// services/backup_service.dart
// Encrypted backup/export (.firewood file) and import

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:cryptography/cryptography.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../database/schemas.dart';
import '../database/isar_service.dart';
import '../security/crypto_service.dart';
import '../models/item_type.dart';
import 'lock_service.dart';
import 'vault_service.dart';

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
        'exported_at': exportedAt.toIso8601String(),
        'vaultId': vaultId,
        'vaultName': vaultName,
        'salt': salt,
        'vault': {
          'id': vaultId,
          'vaultId': vaultId,
          'name': vaultName,
          'vaultName': vaultName,
          'salt': salt,
          'createdAt': exportedAt.toIso8601String(),
          'created_at': exportedAt.toIso8601String(),
        },
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as String?) ?? '1.0.0';

    final exportedAtStr =
        (json['exportedAt'] ?? json['exported_at']) as String?;
    final exportedAt = exportedAtStr != null
        ? DateTime.parse(exportedAtStr)
        : DateTime.now().toUtc();

    final vaultObj = json['vault'] as Map<String, dynamic>?;
    final vaultId = (json['vaultId'] ?? vaultObj?['id'] ?? vaultObj?['vaultId'])
            as String? ??
        'default-vault-id';
    final vaultName = (json['vaultName'] ??
            vaultObj?['name'] ??
            vaultObj?['vaultName']) as String? ??
        'Imported Vault';

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
        'id': itemId,
        'type': type,
        'item_type': type.toLowerCase().replaceAll(' ', ''),
        'title': title,
        'encryptedData': encryptedData,
        'nonce': nonce,
        'encrypted_data': {
          'ciphertext': encryptedData,
          'nonce': nonce,
        },
        'updatedAt': updatedAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory BackupItem.fromJson(Map<String, dynamic> json) {
    final itemId = (json['itemId'] ?? json['id']) as String? ?? '';
    final rawType = (json['type'] ?? json['item_type']) as String? ?? 'login';
    final type = ItemTypeExt.fromString(rawType).label;
    final title = (json['title'] as String?) ?? 'Untitled';

    List<int> encryptedData = [];
    List<int> nonce = [];

    if (json.containsKey('encrypted_data') && json['encrypted_data'] != null) {
      final encData = json['encrypted_data'];
      if (encData is Map) {
        final encMap = Map<String, dynamic>.from(encData);
        encryptedData = List<int>.from((encMap['ciphertext'] as List? ?? []));
        nonce = List<int>.from((encMap['nonce'] as List? ?? []));
      } else if (encData is List) {
        final bytes = List<int>.from(encData);
        try {
          final decodedStr = utf8.decode(bytes);
          final decodedJson = jsonDecode(decodedStr);
          if (decodedJson is Map) {
            encryptedData =
                List<int>.from(decodedJson['ciphertext'] as List? ?? []);
            nonce = List<int>.from(decodedJson['nonce'] as List? ?? []);
          }
        } catch (_) {
          encryptedData = bytes;
          if (json.containsKey('nonce') && json['nonce'] is List) {
            nonce = List<int>.from(json['nonce'] as List);
          }
        }
      }
    }

    if (encryptedData.isEmpty &&
        json.containsKey('encryptedData') &&
        json['encryptedData'] is List) {
      encryptedData = List<int>.from(json['encryptedData'] as List);
    }
    if (nonce.isEmpty && json.containsKey('nonce') && json['nonce'] is List) {
      nonce = List<int>.from(json['nonce'] as List);
    }
    if (encryptedData.isEmpty &&
        json.containsKey('ciphertext') &&
        json['ciphertext'] is List) {
      encryptedData = List<int>.from(json['ciphertext'] as List);
    }

    final updatedAtStr = json['updatedAt'] ?? json['updated_at'];
    final updatedAt = updatedAtStr != null
        ? DateTime.tryParse(updatedAtStr as String) ?? DateTime.now().toUtc()
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
      final verifier =
          await _crypto.encryptString(VaultService.verifierSentinel, key);

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

    // Verify master password and obtain the correct encryption key.
    // V2 vaults: unwrap the MEK from the KWK. V1 vaults: use the KWK directly.
    final SecretKey vaultKey; // MEK for V2, KWK for V1
    final SecretKey
        exportKey; // KWK for backup re-encryption (same as vault.salt derivation)
    try {
      exportKey = await _crypto.deriveKey(masterPassword, vault.salt);

      if (vault.wrappedMekToken != null && vault.wrappedMekNonce != null) {
        // V2: unwrap MEK
        final mekBytes = await _crypto.decryptBoundOrLegacy(
          vault.wrappedMekToken!,
          vault.wrappedMekNonce!,
          exportKey,
          purpose: CryptoService.purposeMekWrap,
        );
        vaultKey = SecretKey(mekBytes);

        // Verify password against MEK's verifier subkey
        if (vault.verifierToken != null && vault.verifierNonce != null) {
          final verifyStr = await _crypto.decryptStringBoundOrLegacy(
            vault.verifierToken!,
            vault.verifierNonce!,
            vaultKey,
            purpose: CryptoService.purposeVerifier,
          );
          if (verifyStr != VaultService.verifierSentinel) {
            throw BackupException('Incorrect master password');
          }
        }
      } else {
        // V1: KWK is the encryption key
        vaultKey = exportKey;
        if (vault.verifierToken != null && vault.verifierNonce != null) {
          final verifyStr = await _crypto.decryptStringBoundOrLegacy(
            vault.verifierToken!,
            vault.verifierNonce!,
            vaultKey,
            purpose: CryptoService.purposeVerifier,
          );
          if (verifyStr != VaultService.verifierSentinel) {
            throw BackupException('Incorrect master password');
          }
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
      // V-028: decrypt with legacy fallback — handles both V2 subkey+AAD
      // items and pre-V-028 raw-key items.
      final plaintext = await _crypto.decryptBoundOrLegacy(
        item.encryptedData,
        item.nonce,
        vaultKey,
        purpose: CryptoService.purposeItems,
        aad: CryptoService.itemAad(item.itemId),
      );

      // V-009: titles/types live inside the ciphertext — read them from the
      // decrypted payload, falling back to the legacy plaintext column.
      final payload =
          jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      final title = (payload['__title'] ??
              (item.title.isNotEmpty ? item.title : 'Untitled'))
          .toString();
      final type =
          (payload['__type'] ?? (item.type.isNotEmpty ? item.type : 'login'))
              .toString();

      // Re-encrypt with export key (fresh nonce) — the backup has its own
      // encryption layer separate from the vault.
      final encrypted = await _crypto.encrypt(plaintext, exportKey);

      backupItems.add(BackupItem(
        itemId: item.itemId,
        type: type,
        title: title,
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

    // Destination. On Android the file is written through the Storage Access
    // Framework (file_picker.saveFile), which needs no storage permission and
    // is Play-policy compliant. Explicit paths (tests, desktop) are unchanged.
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final defaultName = 'firewood-backup-$timestamp$_fileExtension';

    if (customPath == null && Platform.isAndroid) {
      String? saved;
      LockService.beginForegroundFlow();
      try {
        saved = await FilePicker.platform.saveFile(
          fileName: defaultName,
          bytes: Uint8List.fromList(output),
        );
      } finally {
        LockService.endForegroundFlow();
      }
      if (saved == null) {
        throw BackupException('Export cancelled');
      }
      return saved;
    }

    final String filePath;
    if (customPath != null) {
      filePath = customPath.endsWith(_fileExtension)
          ? customPath
          : '$customPath$_fileExtension';
    } else {
      final dir = await _getExportDirectory();
      filePath = '${dir.path}/$defaultName';
    }

    final file = File(filePath);
    await file.writeAsBytes(output, flush: true);

    return filePath;
  }

  /// Desktop export directory. Android uses the Storage Access Framework in
  /// [exportVault] instead (no MANAGE_EXTERNAL_STORAGE, Play-policy compliant).
  Future<Directory> _getExportDirectory() async {
    try {
      if (!Platform.isIOS && !Platform.isAndroid) {
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
      throw BackupException(
          'Incorrect backup password or corrupted backup file.');
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
    final backupItemKey =
        await _crypto.deriveKey(masterPassword, backupData.salt);

    final existingVault = await isar.vaults.where().findFirst();

    if (existingVault != null && !overwrite && activeVaultKey != null) {
      // MERGE MODE: Re-encrypt backup items with current active vault key and add to vault
      // V-028: use items subkey + AAD binding for the active vault key.
      final activeItemKey = await _crypto.deriveSubkey(
          activeVaultKey, CryptoService.purposeItems);
      for (final backupItem in backupData.items) {
        if (backupItem.encryptedData.isEmpty || backupItem.nonce.isEmpty)
          continue;
        // Decrypt plaintext from backup using backup key
        final plaintext = await _crypto.decrypt(
          backupItem.encryptedData,
          backupItem.nonce,
          backupItemKey,
        );

        // V-009: fold metadata into the payload before re-encrypting so the
        // plaintext columns never carry titles/types again.
        final payload =
            jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
        payload.putIfAbsent('__title',
            () => backupItem.title.isNotEmpty ? backupItem.title : 'Untitled');
        payload.putIfAbsent(
            '__type', () => ItemTypeExt.fromString(backupItem.type).label);

        // V-028: re-encrypt with active vault key's items subkey + AAD
        final newId = backupItem.itemId.isNotEmpty
            ? backupItem.itemId
            : const Uuid().v4();
        final reEncrypted = await _crypto.encrypt(
          utf8.encode(jsonEncode(payload)),
          activeItemKey,
          aad: CryptoService.itemAad(newId),
        );

        final item = SecureItem()
          ..itemId = newId
          ..vaultId = existingVault.vaultId
          ..encryptedData = reEncrypted.ciphertext
          ..nonce = reEncrypted.nonce
          ..type = '' // V-009: Zero-Knowledge metadata
          ..title = '' // V-009: Zero-Knowledge metadata
          ..updatedAt = backupItem.updatedAt;

        await isar.writeTxn(() async {
          await isar.secureItems.put(item);
        });
      }
      return '${backupData.vaultName} (${backupData.items.length} items merged)';
    } else {
      // FULL RESTORE MODE: Replace or initialize vault with V2 envelope encryption
      if (overwrite || existingVault != null) {
        await isar.writeTxn(() async {
          await isar.vaults.where().deleteAll();
          await isar.secureItems.where().deleteAll();
        });
      }

      // V-028: create V2 envelope vault.
      // backupItemKey acts as the KWK (derived from master password + backup salt).
      final mekBytes = _crypto.generateRandomBytes(32);
      final mekKey = SecretKey(mekBytes);
      final wrapKey = await _crypto.deriveSubkey(
          backupItemKey, CryptoService.purposeMekWrap);
      final wrappedMek = await _crypto.encrypt(mekBytes, wrapKey);

      final verifierKey =
          await _crypto.deriveSubkey(mekKey, CryptoService.purposeVerifier);
      final verifier = await _crypto.encryptString(
          VaultService.verifierSentinel, verifierKey);

      final vault = Vault()
        ..vaultId = backupData.vaultId
        ..name = backupData.vaultName
        ..salt = backupData.salt
        ..verifierToken = verifier.ciphertext
        ..verifierNonce = verifier.nonce
        ..wrappedMekToken = wrappedMek.ciphertext
        ..wrappedMekNonce = wrappedMek.nonce
        ..version = 2
        ..createdAt = backupData.exportedAt
        ..isDefault = true;

      await isar.writeTxn(() async {
        await isar.vaults.put(vault);
      });

      // Import items with V-028 subkey + AAD
      final itemKey =
          await _crypto.deriveSubkey(mekKey, CryptoService.purposeItems);
      for (final backupItem in backupData.items) {
        if (backupItem.encryptedData.isEmpty || backupItem.nonce.isEmpty)
          continue;
        final plaintext = await _crypto.decrypt(
          backupItem.encryptedData,
          backupItem.nonce,
          backupItemKey,
        );

        // V-009: fold metadata into the payload before re-encrypting so the
        // plaintext columns never carry titles/types again.
        final payload =
            jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
        payload.putIfAbsent('__title',
            () => backupItem.title.isNotEmpty ? backupItem.title : 'Untitled');
        payload.putIfAbsent(
            '__type', () => ItemTypeExt.fromString(backupItem.type).label);

        // V-028: re-encrypt with items subkey + AAD
        final newId = backupItem.itemId.isNotEmpty
            ? backupItem.itemId
            : const Uuid().v4();
        final encrypted = await _crypto.encrypt(
          utf8.encode(jsonEncode(payload)),
          itemKey,
          aad: CryptoService.itemAad(newId),
        );

        final item = SecureItem()
          ..itemId = newId
          ..vaultId = backupData.vaultId
          ..encryptedData = encrypted.ciphertext
          ..nonce = encrypted.nonce
          ..type = '' // V-009: Zero-Knowledge metadata
          ..title = '' // V-009: Zero-Knowledge metadata
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
