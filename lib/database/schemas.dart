// database/schemas.dart
// Isar collections for multi-vault password manager with burner + audit support.
// Run: dart run build_runner build --delete-conflicting-outputs

import 'package:isar/isar.dart';

part 'schemas.g.dart';

@Collection()
class Vault {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String vaultId;

  late String name;

  // 16-byte Argon2id salt, stored in plaintext
  late List<int> salt;

  // Encrypted verification token ("FIREWOOD_VAULT_VERIFY") to validate master password
  List<int>? verifierToken;
  List<int>? verifierNonce;

  // Envelope encryption (V2): random Master Encryption Key wrapped by KWK.
  // Null on V1 legacy vaults — unlock() auto-migrates them to V2.
  List<int>? wrappedMekToken;
  List<int>? wrappedMekNonce;

  // Schema version: 1 = legacy direct key (KWK = encrypt key), 2 = envelope
  // MEK (KWK wraps MEK, MEK encrypts items via HKDF subkeys).
  int version = 1;

  // Whether this vault is the "default" (last used) for quick unlock
  late bool isDefault;

  late DateTime createdAt;
}

@Collection()
class SecureItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String itemId;

  // Parent vault ID – links item to its owning vault
  @Index()
  String vaultId = 'primary_vault';

  // XChaCha20-Poly1305 ciphertext (encrypted JSON bytes)
  late List<int> encryptedData;

  // 24-byte nonce (NOT secret, stored alongside ciphertext)
  late List<int> nonce;

  // V-009: legacy metadata columns — always written as EMPTY strings.
  // Title/type live inside `encryptedData` as `__title`/`__type`; these
  // columns remain only as a read-fallback for rows not yet migrated
  // (migration runs on every verified unlock in VaultService.unlock).
  late String type;

  late String title;

  late DateTime updatedAt;
}

/// Burner password hash – when matched on unlock, triggers full vault destruction.
@Collection()
class BurnerHash {
  Id id = Isar.autoIncrement;

  // Argon2id hash of the burner password (base64 encoded)
  late String passwordHash;

  // Per-entry random 16-byte salt (ADR-006). Null = legacy row hashed with the
  // historic static salt; verification falls back to it until the row is
  // replaced. Never add new salt-less rows.
  List<int>? salt;

  // Human-readable label (e.g., "Duress Code 1")
  late String label;

  late DateTime createdAt;
}
