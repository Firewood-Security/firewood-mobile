# firewood-mobile

Android and iOS password manager — offline-first, zero-knowledge, single vault.
The master password is never written to disk. Every credential field is
individually encrypted with an Argon2id-derived key and XChaCha20-Poly1305 AEAD.
All data remains on the device; there is no account system, no cloud sync, and no
remote telemetry.

Application ID / bundle: **`net.firewood.app`**

---

## Feature overview

| Feature | Notes |
|---|---|
| Single encrypted vault | Argon2id (64 MiB, 3 passes, 4 lanes) key derivation; XChaCha20-Poly1305 per field |
| Credential types | Login, Payment Card, Identity (+ ID image), Secure Note, API Key |
| Biometric unlock | Android Keystore wrapping key gated by `BiometricPrompt`; master password is never stored in plaintext |
| Auto-lock | Configurable 30 s – 30 min timer; pauses on app backgrounding, resumes on foreground |
| Screenshot / recents protection | `FLAG_SECURE` (opt-in in settings) |
| Clipboard auto-clear | 30-second automatic clear after copying a credential field |
| Encrypted backup | `.firewood` export/import via the Storage Access Framework (no storage permission required) |
| P2P vault sharing | Bluetooth Low Energy transport; encrypted payload |
| Password & passphrase generator | Configurable character sets, word lists, PIN mode, strength meter |
| Security advisor | On-device analysis: weak, reused, and aged passwords; missing 2FA |
| Duress / burner passwords | Silent total vault destruction on coercion; no recovery by design |
| In-app updater | HTTPS check against a versioned update manifest; SHA-256 verified download |

---

## Repository layout

```
firewood-mobile/
├── lib/
│   ├── screens/          Vault unlock, setup, home, item detail/view, settings,
│   │                     P2P share, update, about
│   ├── services/         VaultService, ItemService, BackupService, LockService,
│   │                     GeneratorService, BurnerService, BiometricService,
│   │                     NativeSecurityBridge, UpdateService, MiniMLAdvisor
│   ├── security/         CryptoService (Argon2id + XChaCha20-Poly1305 + HKDF)
│   ├── database/         Isar schemas (Vault, SecureItem, BurnerHash) + IsarService
│   ├── providers/        Riverpod state: authProvider, biometric, lock, update
│   ├── models/           ItemType enum, field key constants
│   ├── theme/            AppTheme (Material 3 dark), accent colour service
│   └── widgets/          Design system: App3DButton, AppToast, AppDialog,
│                         CategorySegmentedBar, navigation shell
├── android/
│   ├── app/src/main/kotlin/net/firewood/app/
│   │   ├── MainActivity.kt
│   │   └── security/     SecureKeystoreManager, VaultSecurityBridge,
│   │                     SecureMethodChannel (MethodChannel handler)
│   └── app/proguard-rules.pro
├── ios/
├── test/                 Unit + widget tests; dart_test.yaml pins Argon2id concurrency
└── docs/                 Engineering notes and design decisions
```

---

## Architecture

```
UI (screens/ + widgets/ + theme/)
        │
        ▼
State — flutter_riverpod
  authProvider: SecretKey?   (null = locked)
  biometricAuthEnabledProvider
  lockTimeoutProvider / autoLockProvider
        │
        ▼
Services (services/)
  VaultService · ItemService · BackupService · LockService
  GeneratorService · BurnerService · BiometricService
  NativeSecurityBridge · UpdateService · MiniMLAdvisor
        │
        ▼
Crypto (security/crypto_service.dart)
  Argon2id(m=65536, t=3, p=4, len=32)
  XChaCha20-Poly1305 · HKDF-SHA256 · CSPRNG
        │
        ▼
Persistence (database/)
  Isar — no file-level encryption key
  Plaintext: itemId, vaultId, type, title, updatedAt, nonce
  Ciphertext: encryptedData (XChaCha-sealed JSON fields)
        │
  MethodChannel: com.firewood.vault_security
        ▼
Android Keystore (Kotlin)
  SecureKeystoreManager — AES/GCM wrapping key, biometric + device-credential auth
  VaultSecurityBridge   — wrap / unwrap the password blob
  SecureMethodChannel   — rate-limiting, FLAG_SECURE toggle
```

**Key invariant:** `authProvider` is `non-null` while the vault is unlocked and
`null` at all other times. Every lock path — timer expiry, manual lock, burner
trigger, vault deletion — converges on setting `authProvider` to `null`. The
`SecretKey` never touches the Isar database or any file.

---

## Cryptography

### Key derivation

```
key = Argon2id(
  password = master_password_utf8,
  salt     = vault.salt          // 16 bytes, CSPRNG, stored plaintext in Isar
  m        = 65_536 KiB,         // 64 MiB
  t        = 3,
  p        = 4,
  len      = 32                  // 256-bit output
)
```

### Encryption (per field / per file)

```
nonce      = CSPRNG(24 bytes)    // fresh per operation
ciphertext = XChaCha20-Poly1305.seal(key, nonce, plaintext)
stored     = ciphertext ‖ Poly1305-MAC(16 bytes)
```

### Vault verifier sentinel

On creation, `FIREWOOD_VAULT_VERIFY` (UTF-8) is sealed under the vault key and
stored as the `verifierToken + verifierNonce` pair. On unlock, Argon2id is
re-derived from the entered password and the stored salt; the sentinel is
trial-decrypted. Success = correct password; failure = wrong password or
corruption (indistinguishable by design).

### Biometric wrapping (Android)

1. `SecureKeystoreManager` creates an AES/GCM key in the Android Keystore, gated
   by `BiometricPrompt` (strong biometrics or device credential), with a 60-second
   auth validity window.
2. On biometric enrolment, the master password is AES/GCM-wrapped under this key
   and the blob is stored in `EncryptedSharedPreferences`.
3. On biometric unlock, `BiometricPrompt` authenticates the user; the Keystore
   key is then used to unwrap the blob in the native `SecureMethodChannel`;
   the plaintext password is returned to Dart only for the duration of the
   Argon2id derivation and is not persisted further.

### Backup encryption

```
backup file = salt(16) ‖ nonce(24) ‖ XChaCha20-Poly1305(backup_password, inner_json)
inner_json  = { vaultSalt, verifierToken, verifierNonce, items: [{encryptedData, nonce}] }
```

The backup password is separate from the master password and is subject to the
same ≥ 8-character minimum. Backup files are self-contained; no vault key
material is needed to verify or import them beyond the backup password.

---

## Storage model

| Store | What lives there | Encryption |
|---|---|---|
| Isar database | `Vault`, `SecureItem`, `BurnerHash` collections | Field-level (no Isar file key) |
| `EncryptedSharedPreferences` / Keystore | Biometric wrapping key + wrapped password blob | Android Keystore AES/GCM |
| `SharedPreferences` | Feature flags: biometric enabled, screenshot lock, accent, backup schedule | None (non-sensitive) |
| Storage Access Framework | `.firewood` backup exports, `.env` plaintext exports | XChaCha20 (backups); plaintext (`.env` by design) |

**Plaintext metadata in Isar:** `itemId`, `vaultId`, `type`, `title`,
`updatedAt`, `nonce`. Credential field values are ciphertext only. An attacker
with file-system access to the Isar database can see item titles and types but
not field contents.

---

## Android build & signing

- **`applicationId` / namespace:** `net.firewood.app`
- **Version source of truth:** `pubspec.yaml` `version: X.Y.Z+N` — Gradle reads
  this to set `versionName` and `versionCode`.
- **Release signing:** `android/key.properties` (copy `key.properties.template`
  and fill in your keystore path and credentials). Building with
  `-PrequireReleaseSigning=true` fails hard if the file is absent, preventing an
  accidental debug-signed release upload.
- **R8:** minification and resource shrinking are enabled. ProGuard rules are in
  `android/app/proguard-rules.pro`.
- **Declared permissions:** `USE_BIOMETRIC`, `INTERNET`. File import/export uses
  the Storage Access Framework — no `READ_EXTERNAL_STORAGE` or
  `WRITE_EXTERNAL_STORAGE`. Vault data is excluded from Android Auto Backup.

---

## Development

```bash
flutter pub get
flutter analyze
flutter test                      # dart_test.yaml pins Argon2id test concurrency
flutter run -d <device-or-emulator>
```

### Running only Android-specific tests

```bash
cd android
./gradlew test
```

### Release APK (requires `android/key.properties`)

```bash
flutter build apk --release -PrequireReleaseSigning=true
```

---

## Testing

| Layer | Location | Notes |
|---|---|---|
| Crypto | `test/crypto_service_test.dart` | Argon2id derivation, XChaCha nonce length, AEAD round-trips |
| Vault service | `test/vault_service_test.dart` | Create, unlock, wrong-password rejection |
| Item service | `test/item_service_test.dart` | CRUD, search, category filter |
| Backup | `test/backup_service_test.dart` | Export/import round-trip, wrong-backup-password rejection |
| Widget | `test/widget/` | Smoke tests for unlock and home screens |

`dart_test.yaml` sets `concurrency: 1` for the Argon2id tests to prevent OOM
on memory-constrained CI runners (each invocation uses 64 MiB).

---

## Security boundaries

| Boundary | Protected from | Not protected from |
|---|---|---|
| Isar file | Field content, vault key | Item titles, types, timestamps (plaintext metadata) |
| Android Keystore | Biometric wrapping key extraction | A compromised OS or bootloader |
| Memory (RAM) | Vault key never written to disk | Heap lingering post-lock (no `mlock` / `Zeroize` in Dart) |
| Backup file | Password-guessing (Argon2id-slowed) | Weak backup password (same ≥ 8-char policy as master) |
| Clipboard | Auto-clears after 30 s on credential-view and ENV-copy paths | Three copy paths that do not invoke the auto-clear (known gap) |
| Duress | Coercion — total silent vault destruction | Recovery after destruction (none — by design) |
