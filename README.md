# firewood-mobile

Offline-first, single-vault password manager for Android and iOS. The master
password never touches disk; every vault field is encrypted with Argon2id-
derived keys and XChaCha20-Poly1305, and all data stays on the device.

## Features

- Zero-knowledge single vault with biometric unlock and auto-lock.
- Screenshot/recents protection (`FLAG_SECURE`) and cleared clipboard.
- Encrypted `.firewood` backup export/import through the Storage Access Framework.
- On-device security advisor (weak/reused/old passwords, 2FA gaps).
- Bluetooth P2P sharing of `.firewood` files (native BLE transport).
- Local password & passphrase generator.

## Layout

| Path | Contents |
|---|---|
| `lib/screens/` | unlock, setup, home, credential view/detail, settings, P2P sharing, update, about |
| `lib/services/` | crypto-facing services: vault, backup, file crypto, BLE P2P, advisor, updater |
| `lib/database/` | Isar schemas and service |
| `lib/theme/`, `lib/widgets/` | design system, icons, navigation, dialogs |
| `android/` | Android platform, R8 rules, native security bridge (`net.firewood.app.security`) |
| `ios/` | iOS platform |
| `test/` | unit + widget tests (`dart_test.yaml` pins concurrency for Argon2id) |
| `docs/` | in-repo design/engineering notes |

## Develop

```bash
flutter pub get
flutter analyze
flutter test
```

## Android identity & signing

- `applicationId` / namespace: `net.firewood.app`.
- Version comes from `pubspec.yaml` (`X.Y.Z+N`) — the single source of truth for
  `versionName` and `versionCode`.
- Release builds read `android/key.properties` (see `key.properties.template`).
  A build with `-PrequireReleaseSigning=true` fails if it is missing, so a
  public upload can never be accidentally debug-signed.
- R8 minify + resource shrinking are enabled; keep rules live in
  `android/app/proguard-rules.pro`.
- Declared permissions are only `USE_BIOMETRIC` and `INTERNET`; file
  import/export uses the Storage Access Framework (no storage permission), and
  vault data is excluded from Android backup.
