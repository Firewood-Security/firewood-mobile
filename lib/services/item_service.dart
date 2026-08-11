// services/item_service.dart
// CRUD operations for SecureItems with manual encryption/decryption

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import '../database/isar_service.dart';
import '../database/schemas.dart';
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

  /// Adds a new encrypted item to the vault.
  /// Serializes fields to JSON, encrypts, stores ciphertext + nonce.
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

      // Serialize fields to JSON bytes
      final jsonString = jsonEncode(payloadFields);
      final plaintext = utf8.encode(jsonString);

      // Encrypt with fresh nonce
      final result = await _crypto.encrypt(plaintext, key);

      final vault = await isar.vaults.where().findFirst();
      final vaultId = vault?.vaultId ?? 'primary_vault';

      final now = DateTime.now();
      final item = SecureItem()
        ..itemId = _uuid.v4()
        ..vaultId = vaultId
        ..encryptedData = result.ciphertext
        ..nonce = result.nonce
        ..type = type
        ..title = title.trim()
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
    final isar = await _isarService.instance;

    try {
      final items = await isar.secureItems.where().findAll();
      final decrypted = <DecryptedItem>[];

      for (final item in items) {
        final plaintext = await _crypto.decrypt(
          item.encryptedData,
          item.nonce,
          key,
        );
        final jsonString = utf8.decode(plaintext);
        final fields = jsonDecode(jsonString) as Map<String, dynamic>;

        final createdAtStr = fields['created_at']?.toString();
        final createdAt = createdAtStr != null
            ? (DateTime.tryParse(createdAtStr) ?? item.updatedAt)
            : item.updatedAt;

        decrypted.add(DecryptedItem(
          itemId: item.itemId,
          type: item.type,
          title: item.title,
          fields: fields,
          updatedAt: item.updatedAt,
          createdAt: createdAt,
        ));
      }

      // Sort by updatedAt descending (newest first)
      decrypted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return decrypted;
    } catch (e) {
      throw ItemException('Failed to get items: $e');
    }
  }

  /// Updates an existing item - decrypts, modifies, re-encrypts with FRESH nonce.
  Future<void> updateItem({
    required SecretKey key,
    required String itemId,
    required Map<String, dynamic> newFields,
    String? newTitle,
  }) async {
    final isar = await _isarService.instance;

    try {
      final item = await isar.secureItems
          .filter()
          .itemIdEqualTo(itemId)
          .findFirst();

      if (item == null) {
        throw ItemException('Item not found: $itemId');
      }

      // Note: We need to decrypt first to get existing fields
      final plaintext = await _crypto.decrypt(
        item.encryptedData,
        item.nonce,
        key,
      );
      final existingFields = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      final updatedFields = {...existingFields, ...newFields};

      // Re-encrypt with NEW nonce (critical: never reuse nonce!)
      final jsonString = jsonEncode(updatedFields);
      final newPlaintext = utf8.encode(jsonString);
      final result = await _crypto.encrypt(newPlaintext, key);

      final vault = await isar.vaults.where().findFirst();
      final vaultId = vault?.vaultId ?? 'primary_vault';

      await isar.writeTxn(() async {
        item.vaultId = vaultId;
        item.encryptedData = result.ciphertext;
        item.nonce = result.nonce;
        item.title = newTitle?.trim() ?? item.title;
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
        await isar.secureItems
            .filter()
            .itemIdEqualTo(itemId)
            .deleteAll();
      });
    } catch (e) {
      throw ItemException('Failed to delete item: $e');
    }
  }

  /// Gets a single decrypted item by ID.
  Future<DecryptedItem?> getItem(SecretKey key, String itemId) async {
    final isar = await _isarService.instance;

    try {
      final item = await isar.secureItems
          .filter()
          .itemIdEqualTo(itemId)
          .findFirst();

      if (item == null) return null;

      final plaintext = await _crypto.decrypt(
        item.encryptedData,
        item.nonce,
        key,
      );
      final jsonString = utf8.decode(plaintext);
      final fields = jsonDecode(jsonString) as Map<String, dynamic>;

      return DecryptedItem(
        itemId: item.itemId,
        type: item.type,
        title: item.title,
        fields: fields,
        updatedAt: item.updatedAt,
      );
    } catch (e) {
      throw ItemException('Failed to get item: $e');
    }
  }

  /// Searches items by title (plaintext, no decryption needed).
  Future<List<DecryptedItem>> searchItems(SecretKey key, String query) async {
    final isar = await _isarService.instance;

    try {
      final items = await isar.secureItems
          .filter()
          .titleContains(query, caseSensitive: false)
          .findAll();

      final decrypted = <DecryptedItem>[];
      for (final item in items) {
        final plaintext = await _crypto.decrypt(
          item.encryptedData,
          item.nonce,
          key,
        );
        final jsonString = utf8.decode(plaintext);
        final fields = jsonDecode(jsonString) as Map<String, dynamic>;

        decrypted.add(DecryptedItem(
          itemId: item.itemId,
          type: item.type,
          title: item.title,
          fields: fields,
          updatedAt: item.updatedAt,
        ));
      }

      decrypted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return decrypted;
    } catch (e) {
      throw ItemException('Failed to search items: $e');
    }
  }
}

class ItemException implements Exception {
  final String message;
  ItemException(this.message);
  @override
  String toString() => 'ItemException: $message';
}

// Extension to add helper getter to SecureItem
extension SecureItemExt on SecureItem {
  Map<String, dynamic> get fields {
    // This won't work directly - we need to decrypt first
    // Kept for potential future use
    throw UnsupportedError('Must decrypt item first using ItemService');
  }
}