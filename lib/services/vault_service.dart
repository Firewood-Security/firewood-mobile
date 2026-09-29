// services/vault_service.dart
// Single-vault: one default vault. No vaultId parameters needed.
//
// V2 Envelope Encryption (V-028):
//   1. Argon2id(password, salt) → KWK (Key-Wrapping Key)
//   2. Random 256-bit MEK (Master Encryption Key) generated once
//   3. MEK wrapped by HKDF subkey of KWK (purposeMekWrap)
//   4. Verifier sealed under HKDF subkey of MEK (purposeVerifier)
//   5. Items encrypted under HKDF subkey of MEK (purposeItems) + AAD
//
// V1 legacy vaults (KWK = encryption key) are automatically migrated to V2
// on the first verified unlock. The migration:
//   1. Decrypts all items with the legacy KWK
//   2. Generates a random MEK
//   3. Re-encrypts items with the MEK's items subkey + AAD
//   4. Wraps the MEK and seals a fresh verifier
//
// BURNER PASSWORD: Before vault unlock, the password is checked against
// stored burner hashes. If matched, the vault + items are destroyed.

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import '../database/isar_service.dart';
import '../database/schemas.dart';
import '../debug/crypto_debug.dart';
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
  static const int currentVaultVersion = 2;

  // --- Vault CRUD ---

  /// Creates (or overwrites) the single default vault using V2 envelope encryption.
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
      // KWK derived via Argon2id
      final kwk = await _crypto.deriveKey(password, salt);

      // Random 256-bit Master Encryption Key (MEK)
      final mekBytes = _crypto.generateRandomBytes(32);
      final mekKey = SecretKey(mekBytes);

      // V-028: wrap MEK with HKDF subkey of KWK
      final wrapKey =
          await _crypto.deriveSubkey(kwk, CryptoService.purposeMekWrap);
      final wrappedMek = await _crypto.encrypt(mekBytes, wrapKey);

      // V-028: verifier sealed under HKDF subkey of MEK
      final verifierKey =
          await _crypto.deriveSubkey(mekKey, CryptoService.purposeVerifier);
      final verifier =
          await _crypto.encryptString(_verifierSentinel, verifierKey);

      final vault = Vault()
        ..vaultId = _uuid.v4()
        ..name = vaultName
        ..salt = salt
        ..verifierToken = verifier.ciphertext
        ..verifierNonce = verifier.nonce
        ..wrappedMekToken = wrappedMek.ciphertext
        ..wrappedMekNonce = wrappedMek.nonce
        ..version = currentVaultVersion
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
  /// Returns the in-memory [SecretKey] (MEK for V2, KWK for V1 legacy).
  /// Automatically migrates V1 vaults to V2 on the first verified unlock.
  Future<SecretKey> unlock(String password) async {
    return CryptoDebug.trace('vault.unlock', () async {
      final isar = await _isarService.instance;
      final vault = await isar.vaults.where().findFirst();

      if (vault == null) {
        throw VaultException('No vault found. Create a vault first.');
      }

      final kwk = await _crypto.deriveKey(password, vault.salt);

      // V2 Envelope Vault: unwrap the random MEK
      if (vault.wrappedMekToken != null && vault.wrappedMekNonce != null) {
        // V-035: no verifier means the password cannot be fully checked —
        // the MEK unwrap is the primary check, but a missing verifier signals
        // vault record damage. Refuse to unlock hard.
        if (vault.verifierToken == null || vault.verifierNonce == null) {
          throw VaultException(
              'Vault verifier missing — unlock refused (vault record damaged)');
        }
        try {
          final mekBytes = await _crypto.decryptBoundOrLegacy(
            vault.wrappedMekToken!,
            vault.wrappedMekNonce!,
            kwk,
            purpose: CryptoService.purposeMekWrap,
          );
          final mekKey = SecretKey(mekBytes);

          final sentinel = await _crypto.decryptStringBoundOrLegacy(
            vault.verifierToken!,
            vault.verifierNonce!,
            mekKey,
            purpose: CryptoService.purposeVerifier,
          );
          if (sentinel != _verifierSentinel) {
            throw VaultException('Invalid master password');
          }

          // V-009: clean up any stale plaintext metadata columns
          await _migrateMetadataToPayload(isar, mekKey);

          CryptoDebug.summary('vault.unlock',
              meta: {'format': 'v2-envelope', 'ver': vault.version});
          return mekKey;
        } on VaultException {
          rethrow;
        } catch (_) {
          throw VaultException('Invalid master password');
        }
      }

      // V1 Legacy Vault: direct key verification.
      // V-035: no verifier means the password cannot be checked at all.
      if (vault.verifierToken == null || vault.verifierNonce == null) {
        throw VaultException(
            'Vault verifier missing — unlock refused (vault record damaged)');
      }
      try {
        final sentinel = await _crypto.decryptStringBoundOrLegacy(
          vault.verifierToken!,
          vault.verifierNonce!,
          kwk,
          purpose: CryptoService.purposeVerifier,
        );
        if (sentinel != _verifierSentinel) {
          throw VaultException('Invalid master password');
        }
      } catch (e) {
        if (e is VaultException) rethrow;
        throw VaultException('Invalid master password');
      }

      // V1→V2 migration on first verified unlock (zero data loss).
      await _migrateToV2(isar, vault, kwk, password);

      // After migration, return the MEK (not the KWK).
      final migrated = await isar.vaults.where().findFirst();
      if (migrated?.wrappedMekToken != null &&
          migrated?.wrappedMekNonce != null) {
        final mekBytes = await _crypto.decryptBoundOrLegacy(
          migrated!.wrappedMekToken!,
          migrated.wrappedMekNonce!,
          kwk,
          purpose: CryptoService.purposeMekWrap,
        );
        CryptoDebug.summary('vault.unlock',
            meta: {'format': 'v1-migrated-v2', 'ver': migrated.version});
        return SecretKey(mekBytes);
      }

      // Migration failed to write the V2 record — fall back to returning KWK
      // (old behavior). Next unlock will retry migration.
      CryptoDebug.summary('vault.unlock', meta: {'format': 'v1-fallback'});
      return kwk;
    }, meta: {'vault': 'auto'});
  }

  /// V1→V2 migration: decrypt all items with the legacy KWK, generate a
  /// random MEK, re-encrypt items with the MEK's items subkey + AAD, wrap
  /// the MEK, and upgrade the vault record.
  Future<void> _migrateToV2(
      Isar isar, Vault vault, SecretKey kwk, String password) async {
    // Generate random 256-bit MEK
    final mekBytes = _crypto.generateRandomBytes(32);
    final mekKey = SecretKey(mekBytes);

    // V-028: items subkey of the MEK
    final itemKey =
        await _crypto.deriveSubkey(mekKey, CryptoService.purposeItems);

    // Re-encrypt all items with MEK subkey + AAD
    final items = await isar.secureItems.where().findAll();
    for (final item in items) {
      try {
        final plaintext = await _crypto.decryptBoundOrLegacy(
          item.encryptedData,
          item.nonce,
          kwk,
          purpose: CryptoService.purposeItems,
          aad: CryptoService.itemAad(item.itemId),
        );
        final fields =
            jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;

        // Ensure metadata is in the payload (V-009)
        if (fields['__title']?.toString().isNotEmpty != true) {
          fields['__title'] = item.title.isNotEmpty ? item.title : 'Untitled';
        }
        if (fields['__type']?.toString().isNotEmpty != true) {
          fields['__type'] = item.type.isNotEmpty ? item.type : 'login';
        }
        fields.putIfAbsent(
            'created_at', () => item.updatedAt.toIso8601String());

        final enc = await _crypto.encrypt(
          utf8.encode(jsonEncode(fields)),
          itemKey,
          aad: CryptoService.itemAad(item.itemId),
        );
        await isar.writeTxn(() async {
          item.encryptedData = enc.ciphertext;
          item.nonce = enc.nonce;
          item.title = ''; // V-009: Zero-Knowledge metadata
          item.type = ''; // V-009: Zero-Knowledge metadata
          await isar.secureItems.put(item);
        });
      } catch (_) {
        // Skip undecryptable rows to prevent corruption
      }
    }

    // Wrap MEK with KWK subkey
    final wrapKey =
        await _crypto.deriveSubkey(kwk, CryptoService.purposeMekWrap);
    final wrappedMek = await _crypto.encrypt(mekBytes, wrapKey);

    // V-028: verifier under MEK subkey
    final verifierKey =
        await _crypto.deriveSubkey(mekKey, CryptoService.purposeVerifier);
    final verifier =
        await _crypto.encryptString(_verifierSentinel, verifierKey);

    // Upgrade vault record to V2
    vault
      ..verifierToken = verifier.ciphertext
      ..verifierNonce = verifier.nonce
      ..wrappedMekToken = wrappedMek.ciphertext
      ..wrappedMekNonce = wrappedMek.nonce
      ..version = currentVaultVersion;

    await isar.writeTxn(() async {
      await isar.vaults.put(vault);
    });
  }

  /// V-009: idempotent migration of legacy plaintext metadata columns into
  /// the ciphertext. Called from unlock for V2 vaults that may have stale
  /// title/type columns from before the V-009 fix.
  Future<void> _migrateMetadataToPayload(Isar isar, SecretKey key) async {
    final stale = await isar.secureItems
        .filter()
        .titleIsNotEmpty()
        .or()
        .typeIsNotEmpty()
        .findAll();
    if (stale.isEmpty) return;

    final itemKey = await _crypto.deriveSubkey(key, CryptoService.purposeItems);
    for (final item in stale) {
      try {
        final plaintext = await _crypto.decryptBoundOrLegacy(
          item.encryptedData,
          item.nonce,
          key,
          purpose: CryptoService.purposeItems,
          aad: CryptoService.itemAad(item.itemId),
        );
        final fields =
            jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;

        if (fields['__title']?.toString().isNotEmpty != true) {
          fields['__title'] = item.title.isNotEmpty ? item.title : 'Untitled';
        }
        if (fields['__type']?.toString().isNotEmpty != true) {
          fields['__type'] = item.type.isNotEmpty ? item.type : 'login';
        }

        final enc = await _crypto.encrypt(
          utf8.encode(jsonEncode(fields)),
          itemKey,
          aad: CryptoService.itemAad(item.itemId),
        );
        await isar.writeTxn(() async {
          item.encryptedData = enc.ciphertext;
          item.nonce = enc.nonce;
          item.title = ''; // V-009: never plaintext on disk
          item.type = ''; // V-009: never plaintext on disk
          await isar.secureItems.put(item);
        });
      } catch (_) {
        // Skip undecryptable rows rather than corrupting them.
      }
    }
  }

  // --- Queries ---

  Future<bool> hasAnyVault() async {
    final isar = await _isarService.instance;
    return await isar.vaults.where().count() > 0;
  }

  // --- Deletion ---

  /// Destroys the vault and ALL items. Irreversible.
  /// V-009: deletes the database FILES (page slack dies with them) instead of
  /// clearing rows; the next access recreates an empty database.
  Future<void> burnAllVaults() async {
    await _isarService.wipeDatabaseFiles();
  }

  // --- Exports ---

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
        final sentinel = await _crypto.decryptStringBoundOrLegacy(
            verifierToken, verifierNonce, senderKey,
            purpose: CryptoService.purposeVerifier);
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
        final plaintextBytes = await _crypto.decryptBoundOrLegacy(
          encryptedData, nonce, senderKey,
          purpose: CryptoService.purposeItems,
          aad: const [], // sender items may not have AAD
        );
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
