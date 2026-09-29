// services/item_service.dart
// CRUD operations for SecureItems with V-028 subkey + AAD encryption.
//
// All items are encrypted under an HKDF subkey of the parent key (purposeItems)
// and bound to their record ID via AAD. This means:
//   - Item ciphertext is never directly decryptable as the verifier/wrap key
//   - Copying ciphertext between records breaks the MAC
//   - Pre-V-028 items (raw key, no AAD) are read via decryptBoundOrLegacy

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import '../database/isar_service.dart';
import '../database/schemas.dart';
import '../debug/crypto_debug.dart';
import '../security/crypto_service.dart';

class DecryptedItem {
  final String itemId;
  final String type;
  final String title;
  final Map<String, dynamic> fields;
  final DateTime updatedAt;
  final DateTime createdAt;

  DecryptedItem({
    required this.itemId,
    required this.type,
    required this.title,
    required this.fields,
    required this.updatedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? updatedAt;
}

class ItemService {
  final IsarService _isarService = IsarService();
  final CryptoService _crypto = CryptoService();
  final Uuid _uuid = const Uuid();

  /// V-028: items are encrypted under an HKDF subkey of the parent key so
  /// vault-item ciphertext is never directly decryptable as (or with) the
  /// verifier/wrap key.
  Future<SecretKey> _itemKey(SecretKey parentKey) =>
      _crypto.deriveSubkey(parentKey, CryptoService.purposeItems);

  /// V-028: reads an item with the record-id binding and falls back to the
  /// pre-V-028 raw-key format for rows that predate the binding.
  Future<List<int>> _decryptData(SecureItem item, SecretKey parentKey) =>
      _crypto.decryptBoundOrLegacy(
        item.encryptedData,
        item.nonce,
        parentKey,
        purpose: CryptoService.purposeItems,
        aad: CryptoService.itemAad(item.itemId),
      );

  /// Adds a new encrypted item to the vault.
  /// Serializes fields to JSON, encrypts with V-028 subkey + AAD, stores
  /// ciphertext + nonce.
  Future<String> addItem({
    required SecretKey key,
    required String type,
    required String title,
    required Map<String, dynamic> fields,
  }) async {
    if (title.trim().isEmpty) {
      throw ItemException('Title cannot be empty');
    }

    final isar = await _isarService.instance;

    try {
      final payloadFields = Map<String, dynamic>.from(fields);
      if (!payloadFields.containsKey('created_at')) {
        payloadFields['created_at'] = DateTime.now().toIso8601String();
      }
      // V-009: metadata lives INSIDE the ciphertext.
      payloadFields['__title'] = title.trim();
      payloadFields['__type'] = type;

      final jsonString = jsonEncode(payloadFields);
      final plaintext = utf8.encode(jsonString);

      // V-028: the id exists before encryption so ciphertext is bound to
      // the record it lives in.
      final itemId = _uuid.v4();
      final itemKey = await _itemKey(key);
      final result = await _crypto.encrypt(
        plaintext,
        itemKey,
        aad: CryptoService.itemAad(itemId),
      );

      final vault = await isar.vaults.where().findFirst();
      final vaultId = vault?.vaultId ?? 'primary_vault';

      final now = DateTime.now();
      final item = SecureItem()
        ..itemId = itemId
        ..vaultId = vaultId
        ..encryptedData = result.ciphertext
        ..nonce = result.nonce
        ..type = '' // V-009: Zero-Knowledge metadata
        ..title = '' // V-009: Zero-Knowledge metadata
        ..updatedAt = now;

      await isar.writeTxn(() async {
        await isar.secureItems.put(item);
      });

      return item.itemId;
    } catch (e) {
      if (e is ItemException) rethrow;
      throw ItemException('Failed to add item: $e');
    }
  }

  /// Retrieves and decrypts all items.
  Future<List<DecryptedItem>> getAllItems(SecretKey key) async {
    return CryptoDebug.trace('items.getAllItems', () async {
      final isar = await _isarService.instance;

      try {
        final items = await isar.secureItems.where().findAll();
        final decrypted = <DecryptedItem>[];

        for (final item in items) {
          final plaintext = await _decryptData(item, key);
          final jsonString = utf8.decode(plaintext);
          final fields = jsonDecode(jsonString) as Map<String, dynamic>;

          final createdAtStr = fields['created_at']?.toString();
          final createdAt = createdAtStr != null
              ? (DateTime.tryParse(createdAtStr) ?? item.updatedAt)
              : item.updatedAt;

          decrypted.add(DecryptedItem(
            itemId: item.itemId,
            type: _typeOf(fields, item.type),
            title: _titleOf(fields, item.title),
            fields: _stripInternal(fields),
            updatedAt: item.updatedAt,
            createdAt: createdAt,
          ));
        }

        decrypted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        CryptoDebug.summary('items.getAllItems', meta: {
          'count': decrypted.length,
          'raw_count': items.length,
        });
        return decrypted;
      } catch (e) {
        throw ItemException('Failed to get items: $e');
      }
    }, meta: {'bulk': true});
  }

  /// Updates an existing item — decrypts, modifies, re-encrypts with
  /// V-028 subkey + AAD and a fresh nonce.
  Future<void> updateItem({
    required SecretKey key,
    required String itemId,
    required Map<String, dynamic> newFields,
    String? newTitle,
  }) async {
    final isar = await _isarService.instance;

    try {
      final item =
          await isar.secureItems.filter().itemIdEqualTo(itemId).findFirst();

      if (item == null) {
        throw ItemException('Item not found: $itemId');
      }

      final plaintext = await _decryptData(item, key);
      final existingFields =
          jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      final updatedFields = {...existingFields, ...newFields};
      // V-009: metadata stays inside the ciphertext; columns never written.
      updatedFields['__title'] =
          newTitle?.trim() ?? _titleOf(existingFields, item.title);
      updatedFields['__type'] = _typeOf(existingFields, item.type);

      // V-028: re-encrypt with subkey + AAD and a fresh nonce.
      final itemKey = await _itemKey(key);
      final result = await _crypto.encrypt(
        utf8.encode(jsonEncode(updatedFields)),
        itemKey,
        aad: CryptoService.itemAad(item.itemId),
      );

      final vault = await isar.vaults.where().findFirst();
      final vaultId = vault?.vaultId ?? 'primary_vault';

      await isar.writeTxn(() async {
        item.vaultId = vaultId;
        item.encryptedData = result.ciphertext;
        item.nonce = result.nonce;
        item.title = ''; // V-009: Zero-Knowledge metadata
        item.type = ''; // V-009: Zero-Knowledge metadata
        item.updatedAt = DateTime.now();
        await isar.secureItems.put(item);
      });
    } catch (e) {
      if (e is ItemException) rethrow;
      throw ItemException('Failed to update item: $e');
    }
  }

  /// Deletes an item (no decryption needed).
  Future<void> deleteItem(String itemId) async {
    final isar = await _isarService.instance;

    try {
      await isar.writeTxn(() async {
        await isar.secureItems.filter().itemIdEqualTo(itemId).deleteAll();
      });
    } catch (e) {
      throw ItemException('Failed to delete item: $e');
    }
  }

  /// Gets a single decrypted item by ID.
  Future<DecryptedItem?> getItem(SecretKey key, String itemId) async {
    final isar = await _isarService.instance;

    try {
      final item =
          await isar.secureItems.filter().itemIdEqualTo(itemId).findFirst();

      if (item == null) return null;

      final plaintext = await _decryptData(item, key);
      final jsonString = utf8.decode(plaintext);
      final fields = jsonDecode(jsonString) as Map<String, dynamic>;

      return DecryptedItem(
        itemId: item.itemId,
        type: _typeOf(fields, item.type),
        title: _titleOf(fields, item.title),
        fields: _stripInternal(fields),
        updatedAt: item.updatedAt,
      );
    } catch (e) {
      throw ItemException('Failed to get item: $e');
    }
  }

  /// Searches items by title — V-009: titles live inside the ciphertext, so
  /// search runs over decrypted items instead of a plaintext column query.
  Future<List<DecryptedItem>> searchItems(SecretKey key, String query) async {
    final all = await getAllItems(key);
    final q = query.toLowerCase();
    return all
        .where((item) =>
            item.title.toLowerCase().contains(q) ||
            item.type.toLowerCase().contains(q) ||
            item.fields.values
                .any((v) => v.toString().toLowerCase().contains(q)))
        .toList();
  }

  /// V-009: title from the decrypted payload, with the legacy plaintext
  /// column as fallback for rows migrated before the first unlock.
  static String _titleOf(Map<String, dynamic> fields, String column) {
    final t = fields['__title']?.toString();
    if (t != null && t.isNotEmpty) return t;
    return column.isNotEmpty ? column : 'Untitled';
  }

  /// V-009: type from the decrypted payload, with column fallback.
  static String _typeOf(Map<String, dynamic> fields, String column) {
    final t = fields['__type']?.toString();
    if (t != null && t.isNotEmpty) return t;
    return column.isNotEmpty ? column : 'login';
  }

  /// V-009: internal envelope keys are never exposed to callers.
  static Map<String, dynamic> _stripInternal(Map<String, dynamic> fields) =>
      Map<String, dynamic>.from(fields)
        ..remove('__title')
        ..remove('__type');
}

class ItemException implements Exception {
  final String message;
  ItemException(this.message);
  @override
  String toString() => 'ItemException: $message';
}
