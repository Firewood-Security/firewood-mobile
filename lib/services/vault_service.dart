// services/vault_service.dart
// Single-vault: one default vault. No vaultId parameters needed.
//
// BURNER PASSWORD: Before vault unlock, the password is checked against
// stored burner hashes. If matched, the vault + items are destroyed.

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import '../database/isar_service.dart';
import '../database/schemas.dart';
import '../security/crypto_service.dart';
import 'item_service.dart';

class VaultService {
  final IsarService _isarService = IsarService();
  final CryptoService _crypto = CryptoService();
  final Uuid _uuid = const Uuid();

  /// Sentinel plaintext sealed under the vault key to verify passwords.
  /// Single owned constant (previously duplicated as a literal in
  /// BackupService) — changing it is a Data-model + migration event.
  static const String verifierSentinel = 'FIREWOOD_VAULT_VERIFY';
  static const String _verifierSentinel = verifierSentinel;

  // --- Vault CRUD ---

  /// Creates (or overwrites) the single default vault.
  Future<void> createVault(String password,
      {String vaultName = 'Primary Vault'}) async {
    if (password.length < 8) {
      throw VaultException('Master password must be at least 8 characters');
    }

    final isar = await _isarService.instance;

    try {
      // Destroy any existing vault first
      await isar.writeTxn(() async {
        await isar.secureItems.where().deleteAll();
        await isar.vaults.where().deleteAll();
      });

      final salt = _crypto.generateSalt();
      final key = await _crypto.deriveKey(password, salt);
      final verifier = await _crypto.encryptString(_verifierSentinel, key);

      final vault = Vault()
        ..vaultId = _uuid.v4()
        ..name = vaultName
        ..salt = salt
        ..verifierToken = verifier.ciphertext
        ..verifierNonce = verifier.nonce
        ..isDefault = true
        ..createdAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.vaults.put(vault);
      });
    } catch (e) {
      if (e is VaultException) rethrow;
      throw VaultException('Failed to create vault: $e');
    }
  }

  /// Unlocks the single default vault with [password].
  /// Returns the derived [SecretKey].
  /// Throws if no vault exists or password is wrong.
  Future<SecretKey> unlock(String password) async {
    final isar = await _isarService.instance;
    final vault = await isar.vaults.where().findFirst();

    if (vault == null) {
      throw VaultException('No vault found. Create a vault first.');
    }

    final key = await _crypto.deriveKey(password, vault.salt);

    if (vault.verifierToken != null && vault.verifierNonce != null) {
      try {
        final decrypted = await _crypto.decryptString(
            vault.verifierToken!, vault.verifierNonce!, key);
        if (decrypted != _verifierSentinel) {
          throw VaultException('Invalid master password');
        }
      } catch (e) {
        if (e is VaultException) rethrow;
        throw VaultException('Invalid master password');
      }
    }

    return key;
  }

  // --- Queries ---

  Future<bool> hasAnyVault() async {
    final isar = await _isarService.instance;
    return await isar.vaults.where().count() > 0;
  }

  // --- Deletion ---

  /// Destroys the vault and ALL items. Irreversible.
  Future<void> burnAllVaults() async {
    final isar = await _isarService.instance;
    await isar.writeTxn(() async {
      await isar.secureItems.where().deleteAll();
      await isar.vaults.where().deleteAll();
      await isar.burnerHashs.where().deleteAll();
    });
  }

  // --- Exports ---

  Future<Map<String, dynamic>> exportVault() async {
    final isar = await _isarService.instance;
    var vault = await isar.vaults.where().findFirst();
    if (vault == null) {
      final salt = _crypto.generateSalt();
      vault = Vault()
        ..vaultId = _uuid.v4()
        ..name = 'Primary Vault'
        ..salt = salt
        ..isDefault = true
        ..createdAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.vaults.put(vault!);
      });
    }

    final items = await isar.secureItems.where().findAll();

    return {
      'vaultVersion': '2.0',
      'vaultId': vault.vaultId,
      'vaultName': vault.name,
      'salt': vault.salt,
      'verifierToken': vault.verifierToken,
      'verifierNonce': vault.verifierNonce,
      'createdAt': vault.createdAt.toIso8601String(),
      'items': items
          .map((item) => {
                'id': item.itemId,
                'type': item.type,
                'title': item.title,
                'encryptedData': item.encryptedData,
                'nonce': item.nonce,
                'updatedAt': item.updatedAt.toIso8601String(),
              })
          .toList(),
    };
  }

  Future<void> importVaultPayload(Map<String, dynamic> payload) async {
    final isar = await _isarService.instance;

    final salt = (payload['salt'] as List).cast<int>();
    final verifierToken = payload['verifierToken'] != null
        ? (payload['verifierToken'] as List).cast<int>()
        : null;
    final verifierNonce = payload['verifierNonce'] != null
        ? (payload['verifierNonce'] as List).cast<int>()
        : null;
    final vaultName = payload['vaultName'] as String? ?? 'Imported Vault';
    final vaultId = _uuid.v4();

    final itemsList = (payload['items'] as List? ?? []);

    await isar.writeTxn(() async {
      final newVault = Vault()
        ..vaultId = vaultId
        ..name = vaultName
        ..salt = salt
        ..verifierToken = verifierToken
        ..verifierNonce = verifierNonce
        ..isDefault = true
        ..createdAt = DateTime.now();
      await isar.vaults.put(newVault);

      for (final rawItem in itemsList) {
        final itemMap = rawItem as Map<String, dynamic>;
        final secureItem = SecureItem()
          ..itemId = itemMap['id'] as String? ?? _uuid.v4()
          ..vaultId = vaultId
          ..type = itemMap['type'] as String? ?? 'login'
          ..title = itemMap['title'] as String? ?? 'Untitled'
          ..encryptedData = (itemMap['encryptedData'] as List).cast<int>()
          ..nonce = (itemMap['nonce'] as List).cast<int>()
          ..updatedAt = itemMap['updatedAt'] != null
              ? DateTime.parse(itemMap['updatedAt'] as String)
              : DateTime.now();
        await isar.secureItems.put(secureItem);
      }
    });
  }

  Future<int> decryptAndImportVaultItems({
    required String senderPassword,
    required Map<String, dynamic> vaultPayload,
    required SecretKey recipientKey,
  }) async {
    final itemsList = (vaultPayload['items'] as List? ?? []);
    final salt = (vaultPayload['salt'] as List).cast<int>();
    final verifierToken = vaultPayload['verifierToken'] != null
        ? (vaultPayload['verifierToken'] as List).cast<int>()
        : null;
    final verifierNonce = vaultPayload['verifierNonce'] != null
        ? (vaultPayload['verifierNonce'] as List).cast<int>()
        : null;

    final senderKey = await _crypto.deriveKey(senderPassword, salt);

    if (verifierToken != null && verifierNonce != null) {
      try {
        final sentinel = await _crypto.decryptString(
            verifierToken, verifierNonce, senderKey);
        if (sentinel != _verifierSentinel) {
          throw VaultException('Invalid sender master password');
        }
      } catch (_) {
        throw VaultException('Invalid sender master password');
      }
    }

    final itemService = ItemService();
    int importedCount = 0;
    for (final rawItem in itemsList) {
      try {
        final itemMap = Map<String, dynamic>.from(rawItem as Map);
        final encryptedData = (itemMap['encryptedData'] as List).cast<int>();
        final nonce = (itemMap['nonce'] as List).cast<int>();
        final plaintextBytes =
            await _crypto.decrypt(encryptedData, nonce, senderKey);
        final fieldsJson = utf8.decode(plaintextBytes);
        final fields = jsonDecode(fieldsJson) as Map<String, dynamic>;

        await itemService.addItem(
          key: recipientKey,
          type: itemMap['type']?.toString() ?? 'login',
          title: itemMap['title']?.toString() ?? 'Imported Item',
          fields: fields,
        );
        importedCount++;
      } catch (_) {}
    }
    return importedCount;
  }
}

class VaultException implements Exception {
  final String message;
  VaultException(this.message);
  @override
  String toString() => 'VaultException: $message';
}
