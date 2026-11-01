<div align="center">

# Firewood Mobile

**Local-first, zero-knowledge credential vault for Android and iOS.**  
No cloud accounts. No remote servers. No telemetry.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-2ea44f.svg)](#supported-platforms)
[![Crypto](https://img.shields.io/badge/Crypto-Argon2id%20%2B%20XChaCha20--Poly1305-orange.svg)](#cryptographic-architecture)
[![Download](https://img.shields.io/badge/Download-Release%20Binaries-brightgreen.svg)](https://firewoodsec.yahyaoncloud.com/download/)

</div>

---

## Overview

**Firewood** is an offline-first password and credential manager built for uncompromising privacy and security. Your master password is never stored on disk. Every single credential field is independently encrypted in RAM using **Argon2id** key derivation and **XChaCha20-Poly1305** authenticated encryption before touching persistent storage.

All data remains exclusively on your physical device.

---

## Key Features

- **Zero-Knowledge Encryption**: Master key derived using Argon2id (64 MiB RAM, 3 iterations, 4 lanes). Each item field is sealed with XChaCha20-Poly1305 and unique 24-byte CSPRNG nonces.
- **Multiple Credential Types**: Secure storage for Logins, Payment Cards, Identities (+ encrypted ID card photos), Secure Notes, and API Keys.
- **Hardware-Backed Biometrics**: Android Keystore AES-256-GCM wrapping key gated by `BiometricPrompt` (strong biometrics or device PIN). The master password is never stored in plaintext.
- **Auto-Lock Protection**: Configurable inactivity lock timer (30 seconds to 30 minutes). Automatically pauses in the background and re-authenticates on foreground entry.
- **Screen & Screenshot Protection**: System-level `FLAG_SECURE` prevents screenshots, screen recording, and app switcher preview capture.
- **Clipboard Auto-Clear**: Automatically wipes copied passwords and sensitive tokens from the system clipboard after 30 seconds.
- **P2P AirShare Sync**: Encrypted peer-to-peer credential sharing across nearby devices over Bluetooth Low Energy (BLE) without intermediate servers.
- **Password & Passphrase Generator**: Generate cryptographically strong random passwords, EFF diceware passphrases, and secure PINs with live entropy strength calculation.
- **On-Device Security Advisor**: Proactive offline analysis for weak, reused, or expired credentials and missing multi-factor authentication.
- **Duress Burner Wipe**: Optional emergency burner PIN that silently and permanently wipes the entire database when coerced, leaving no recoverable traces.
- **Self-Contained Backups**: Encrypted `.firewood` backup export and restore using the Storage Access Framework (SAF) without requesting broad storage permissions.

---

## Download & Installation

### Official Releases
Official production builds are cryptographically signed with our pinned release key and published with verifiable SHA-256 checksums:

- **Web Distribution Portal**: [firewoodsec.yahyaoncloud.com/download](https://firewoodsec.yahyaoncloud.com/download/)
- **GitHub Release Mirror**: [github.com/Firewood-Security](https://github.com/Firewood-Security)
- **F-Droid Store**: `net.firewood.app` *(recommended for FOSS devices)*
- **Google Play Store**: [Firewood on Google Play](https://play.google.com/store/apps/details?id=net.firewood.app)

### Verifying Checksums
After downloading the standalone APK, verify its cryptographic hash against the official manifest:

```bash
sha256sum firewood-latest-android.apk
```

---

## Cryptographic Architecture

```
Master Password (entered by user)
  + Random Vault Salt (16 bytes, stored in Isar)
       │
       ▼
  Argon2id (m=65536 KiB, t=3, p=4, 256-bit output)
       │
       ▼
  Vault Master Key (RAM only, never touches disk)
       │
       ├──► Sentinel Verification (trial-decrypts FIREWOOD_VAULT_VERIFY)
       │
       └──► XChaCha20-Poly1305 AEAD per field
            ├── Nonce: 24 bytes fresh CSPRNG per seal
            └── Ciphertext: JSON-encoded sensitive payload + 16-byte Poly1305 tag
```

### Storage Security Model

| Store | Data Stored | Encryption Mechanism |
|---|---|---|
| **Isar Local DB** | `Vault`, `SecureItem`, `BurnerHash` | Field-level XChaCha20-Poly1305 (metadata title/type plaintext) |
| **Android Keystore** | Biometric Wrapping Key + Master Blob | Native AES-256-GCM hardware key (`BiometricPrompt` authenticated) |
| **SharedPreferences** | UI Settings & Feature Flags | Plaintext (strictly non-sensitive preferences) |
| **Storage Access Framework** | `.firewood` Backup Archives | Argon2id + XChaCha20-Poly1305 under independent backup password |

---

## Repository Layout

```
firewood-mobile/
├── lib/
│   ├── database/         Isar database schemas (Vault, SecureItem, BurnerHash) & service
│   ├── models/           Credential types (Login, Card, Note, Identity, API Key)
│   ├── providers/        Riverpod state management (authProvider, lock, biometrics)
│   ├── screens/          Unlock, setup, vault home, credential detail, settings, AirShare
│   ├── security/         CryptoService (Argon2id, XChaCha20-Poly1305, HKDF, CSPRNG)
│   ├── services/         Vault, items, backup, lock, burner, generator, updates
│   ├── theme/            Dark Zinc Technical Vault design system & tokens
│   └── widgets/          AppButton, AppDialog, AppToast, CategoryBar, AppLoader
├── android/
│   ├── app/src/main/     Kotlin security bridges (SecureKeystoreManager, MethodChannel)
│   └── app/              Proguard rules and Android app manifests
├── ios/                  iOS platform embedding
├── test/                 Unit and widget test suites
├── CONTRIBUTING.md       Contribution guide and coding standards
├── SECURITY.md           Security policy and responsible disclosure
└── AGENTS.md             Architecture invariants and UI component guidelines
```

---

## Development & Building

### Prerequisites
- [Flutter SDK](https://flutter.dev) `3.47.5+` (pinned stable)
- [Dart SDK](https://dart.dev) matching Flutter
- Android SDK (API 34+ build-tools)
- Java 17 or 21 (OpenJDK)

### Quickstart

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Verify static analysis & code formatting**:
   ```bash
   dart format --output=none --set-exit-if-changed lib test
   flutter analyze lib/ --fatal-warnings --no-fatal-infos
   ```

3. **Run test suite**:
   ```bash
   flutter test test/ --reporter compact
   ```
   *(Note: `dart_test.yaml` sets concurrency to 1 for Argon2id tests to prevent memory exhaustion on constrained environments).*

4. **Launch debug app on a connected device/emulator**:
   ```bash
   flutter run
   ```

### Building Release APK

To produce a production-signed APK:
1. Copy `android/key.properties.template` to `android/key.properties`.
2. Fill in your keystore credentials.
3. Build the release APK:
   ```bash
   flutter build apk --release
   ```

*(For testing without a release key, pass `-PrequireReleaseSigning=false` to generate an explicit QA build).*

---

## Contributing

We welcome community contributions, bug reports, and security audits! Please review our [Contribution Guidelines](CONTRIBUTING.md) and [Coding Standards](AGENTS.md) before submitting a pull request.

---

## Security & Vulnerability Reporting

Security is our highest priority. If you discover a potential vulnerability, please consult our [Security Policy](SECURITY.md) for responsible disclosure procedures. Please do not report security issues via public GitHub issues.

---

## License

This project is licensed under the [MIT License](LICENSE).
