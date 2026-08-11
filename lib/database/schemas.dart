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

  // Item type: login, card, note, identity, developerSecret
  late String type;

  // Plaintext title for search/display without decryption
  late String title;

  late DateTime updatedAt;
}

/// Burner password hash – when matched on unlock, triggers full vault destruction.
@Collection()
class BurnerHash {
  Id id = Isar.autoIncrement;

  // Argon2id hash of the burner password (base64 encoded)
  late String passwordHash;

  // Human-readable label (e.g., "Duress Code 1")
  late String label;

  late DateTime createdAt;
}
