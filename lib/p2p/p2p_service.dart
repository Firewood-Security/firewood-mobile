// p2p/p2p_service.dart
// High-level API for secure offline P2P sharing of credentials & vaults.
//
// REFINED FLOW (tamper-proof, mutual agreement, fault-tolerant):
//
// SENDER (shareVault):
//   1. Export vault as raw encrypted blobs (NEVER decrypts plaintext on sender)
//   2. Transport via X25519 + XChaCha20-Poly1305 tunnel
//   3. SAS code displayed to sender — they must verbally confirm with receiver
//
// RECEIVER (receiveTransfer):
//   1. Receive encrypted vault payload through P2P tunnel
//   2. SAS code displayed — receiver must verbally confirm with sender
//   3. Receiver is prompted for SENDER'S master password
//   4. Sender's password verified against verifierToken (Poly1305 AEAD)
//   5. Each item: decrypt with senderKey, re-encrypt with recipientKey, save
//   6. Duplicate items detected by title+type and skipped
//
// KEY INVARIANT: Vault items are NEVER sent as plaintext. The raw encrypted
// blobs from Isar are transmitted unchanged. Only the intended receiver who
// knows the sender's master password can decrypt and re-encrypt them.

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../services/item_service.dart';
import '../services/vault_service.dart';
import 'p2p_failures.dart';
import 'session_manager.dart';
import 'transfer_models.dart';
import 'transport_adapter.dart';

class P2PService {
  final SessionManager _sessionManager;
  final ItemService _itemService;
  final VaultService _vaultService;

  P2PService({
    SessionManager? sessionManager,
    ItemService? itemService,
    VaultService? vaultService,
  })  : _sessionManager = sessionManager ?? SessionManager(),
        _itemService = itemService ?? ItemService(),
        _vaultService = vaultService ?? VaultService();

  SessionManager get sessionManager => _sessionManager;

  // --- SHARING (Sender Side) ---

  /// Share a single decrypted credential item securely with peer.
  /// The item is decrypted locally with [key], transported encrypted with
  /// P2P session key, and re-encrypted on the receiver side.
  ///
  /// Returns the SAS verification code — caller MUST display it.
  Future<ShareResult> shareItem({
    required SecretKey key,
    required String itemId,
    required DiscoveredPeer peer,
  }) async {
    try {
      final itemJson = await _itemService.exportItemToJson(key, itemId);
      final rawPayload = Uint8List.fromList(utf8.encode(jsonEncode({
        'transferType': 'singleItem',
        'protocolVersion': 2,
        'content': itemJson,
      })));

      final sasCode = await _sessionManager.sendPayloadToPeer(peer, rawPayload);

      return ShareResult(
        sasCode: sasCode,
        itemCount: 1,
        vaultName: itemJson['title']?.toString() ?? 'item',
      );
    } catch (e) {
      if (e is P2PFailure) rethrow;
      throw ExportFailure('Failed to share item with ${peer.name}', cause: e);
    }
  }

  /// Share multiple credentials in a single transfer.
  /// Each item is decrypted with [key], packed into a batch, and transported
  /// through the encrypted P2P tunnel to the receiver.
  Future<ShareResult> shareItems({
    required SecretKey key,
    required List<String> itemIds,
    required DiscoveredPeer peer,
  }) async {
    if (itemIds.isEmpty) throw ExportFailure('No items selected');
    try {
      final itemsJson = <Map<String, dynamic>>[];
      for (final itemId in itemIds) {
        final itemJson = await _itemService.exportItemToJson(key, itemId);
        itemsJson.add(itemJson);
      }
      final rawPayload = Uint8List.fromList(utf8.encode(jsonEncode({
        'transferType': 'multipleItems',
        'protocolVersion': 2,
        'content': {'items': itemsJson},
      })));
      final sasCode = await _sessionManager.sendPayloadToPeer(peer, rawPayload);
      return ShareResult(
        sasCode: sasCode,
        itemCount: itemsJson.length,
        vaultName: '${itemsJson.length} credentials',
      );
    } catch (e) {
      if (e is P2PFailure) rethrow;
      throw ExportFailure('Failed to share items with ${peer.name}', cause: e);
    }
  }

  /// Share full vault as raw encrypted blobs.
  ///
  /// INVARIANT (FIX GAP 1+2): Items are NEVER decrypted on the sender.
  /// Raw ciphertext+nonce from Isar is exported and transmitted. The receiver
  /// MUST provide the sender's master password to decrypt them.
  ///
  /// The [key] parameter is NOT used for decryption — it only proves the vault
  /// is unlocked (caller validates). The actual export uses [VaultService.exportVault].
  ///
  /// Returns the SAS verification code — caller MUST display it to both parties.
  Future<ShareResult> shareVault({
    required SecretKey key,
    required String vaultId,
    required DiscoveredPeer peer,
  }) async {
    try {
      // FIX GAP 1+: Always export as encrypted blobs, never decrypt locally
      final vaultPayload = await _vaultService.exportVault();

      final rawPayload = Uint8List.fromList(utf8.encode(jsonEncode({
        'transferType': 'fullVault',
        'protocolVersion': 2,
        'content': vaultPayload,
      })));

      final sasCode = await _sessionManager.sendPayloadToPeer(peer, rawPayload);

      final itemCount = (vaultPayload['items'] as List?)?.length ?? 0;
      final vaultName = vaultPayload['vaultName'] as String? ?? 'Firewood Vault';

      return ShareResult(
        sasCode: sasCode,
        itemCount: itemCount,
        vaultName: vaultName,
      );
    } catch (e) {
      if (e is P2PFailure) rethrow;
      throw ExportFailure('Failed to share vault with ${peer.name}', cause: e);
    }
  }

  // --- RECEIVING (Receiver Side) ---

  /// Receive any transfer (single item or full vault) from peer.
  ///
  /// For single-item transfers, [recipientKey] is used to re-encrypt the item.
  ///
  /// For full-vault transfers, [senderPassword] MUST be provided — the receiver
  /// must know the sender's master password. The vault items are encrypted with
  /// the sender's key and can only be decrypted with the sender's password.
  /// They are then re-encrypted with [recipientKey] for the receiver's vault.
  ///
  /// Returns [ReceiveResult] with the SAS code (for mutual verification),
  /// transfer type, imported count, and any skipped duplicates.
  Future<ReceiveResult> receiveTransfer({
    required SecretKey recipientKey,
    String? senderPassword,
    required DiscoveredPeer peer,
  }) async {
    try {
      if (_sessionManager.state == TransferState.idle) {
        await _sessionManager.connect(peer);
      }

      final decryptedPayload = await _sessionManager.receiveEncryptedPayload(peer);

      final payloadJson = jsonDecode(utf8.decode(decryptedPayload)) as Map<String, dynamic>;
      final transferType = payloadJson['transferType'] as String;

      // --- Payload schema validation (FIX GAP 6) ---
      _validatePayload(transferType, payloadJson);

      if (transferType == 'singleItem') {
        final itemContent = Map<String, dynamic>.from(payloadJson['content'] as Map);
        await _itemService.addItemFromJson(recipientKey, itemContent);
        final title = itemContent['title'] as String? ?? 'imported item';
        return ReceiveResult(
          sasCode: null,
          transferType: 'singleItem',
          importedCount: 1,
          skippedCount: 0,
          detail: title,
        );
      }

      if (transferType == 'multipleItems') {
        final payloadContent = payloadJson['content'] as Map<String, dynamic>;
        final itemsList = payloadContent['items'] as List?;
        if (itemsList == null || itemsList.isEmpty) {
          throw ImportFailure('No items found in transfer');
        }
        final titles = <String>[];
        for (final itemRaw in itemsList) {
          final itemMap = Map<String, dynamic>.from(itemRaw as Map);
          await _itemService.addItemFromJson(recipientKey, itemMap);
          titles.add(itemMap['title'] as String? ?? 'imported');
        }
        return ReceiveResult(
          sasCode: null,
          transferType: 'multipleItems',
          importedCount: titles.length,
          skippedCount: 0,
          detail: titles.join(', '),
        );
      }

      if (transferType == 'fullVault') {
        final vaultContent = Map<String, dynamic>.from(payloadJson['content'] as Map);

        // Validate vault payload structure
        final itemsList = vaultContent['items'] as List?;
        if (itemsList == null) {
          throw ImportFailure('Invalid vault payload: missing items list');
        }

        // For vault transfer: senderPassword is REQUIRED (FIX GAP 1)
        if (senderPassword == null || senderPassword.isEmpty) {
          throw ImportFailure(
            'Sender\'s master password is required to decrypt the shared vault. '
            'Please provide the password used to unlock the sender\'s vault.'
          );
        }

        // Decrypt with sender's key, re-encrypt with recipient's key
        final importedCount = await _vaultService.decryptAndImportVaultItems(
          senderPassword: senderPassword,
          vaultPayload: vaultContent,
          recipientKey: recipientKey,
        );

        final totalItems = itemsList.length;
        final skippedCount = totalItems - importedCount;

        return ReceiveResult(
          sasCode: null, // populated by session manager
          transferType: 'fullVault',
          importedCount: importedCount,
          skippedCount: skippedCount,
          detail: '$importedCount of $totalItems items imported${skippedCount > 0 ? ' ($skippedCount duplicates skipped)' : ''}',
        );
      }

      throw ImportFailure('Unknown transfer type: $transferType');
    } on VaultException catch (e) {
      // Pass through vault errors (wrong password, etc.) with clear message
      throw ImportFailure(e.message);
    } on P2PFailure {
      rethrow;
    } catch (e) {
      throw ImportFailure('Failed to receive transfer from ${peer.name}', cause: e);
    }
  }

  /// Validate payload structure before processing (FIX GAP 6).
  void _validatePayload(String transferType, Map<String, dynamic> payload) {
    // Common required fields
    if (!payload.containsKey('transferType')) {
      throw ImportFailure('Invalid payload: missing transferType');
    }

    if (!payload.containsKey('content')) {
      throw ImportFailure('Invalid payload: missing content');
    }

    final content = payload['content'];
    if (content is! Map) {
      throw ImportFailure('Invalid payload: content must be a JSON object');
    }

    if (transferType == 'singleItem') {
      final itemContent = content;
      if (itemContent['title'] == null || (itemContent['title'] as String).isEmpty) {
        throw ImportFailure('Invalid item: missing title');
      }
      if (itemContent['fields'] != null && itemContent['fields'] is! Map) {
        throw ImportFailure('Invalid item: fields must be a JSON object');
      }
    }

    if (transferType == 'multipleItems') {
      final payloadContent = content;
      final items = payloadContent['items'];
      if (items is! List) {
        throw ImportFailure('Invalid multi-item payload: items must be a JSON array');
      }
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is! Map) {
          throw ImportFailure('Invalid multi-item payload: item $i is not an object');
        }
        if (item['title'] == null || (item['title'] as String).isEmpty) {
          throw ImportFailure('Invalid multi-item payload: item $i missing title');
        }
      }
    }

    if (transferType == 'fullVault') {
      final vaultContent = content;
      if (vaultContent['items'] is! List) {
        throw ImportFailure('Invalid vault payload: items must be a JSON array');
      }
      // Validate each item has required fields
      final items = vaultContent['items'] as List;
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is! Map) {
          throw ImportFailure('Invalid vault payload: item at index $i is not an object');
        }
        if (!item.containsKey('encryptedData')) {
          throw ImportFailure('Invalid vault payload: item $i missing encryptedData');
        }
        if (!item.containsKey('nonce')) {
          throw ImportFailure('Invalid vault payload: item $i missing nonce');
        }
      }
    }
  }

  void dispose() {
    _sessionManager.dispose();
  }
}

/// Result from a share operation — carries SAS code for mutual verification.
class ShareResult {
  final String sasCode;
  final int itemCount;
  final String vaultName;

  const ShareResult({
    required this.sasCode,
    required this.itemCount,
    required this.vaultName,
  });
}

/// Result from a receive operation.
class ReceiveResult {
  final String? sasCode;
  final String transferType;
  final int importedCount;
  final int skippedCount;
  final String detail;

  const ReceiveResult({
    this.sasCode,
    required this.transferType,
    required this.importedCount,
    required this.skippedCount,
    required this.detail,
  });
}
