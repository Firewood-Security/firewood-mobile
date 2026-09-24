# firewood-mobile

Offline-first, single-vault password manager for Android and iOS. This is the
Play Store / F-Droid client (`net.firewood.app`).

## Status

Flutter app with a local encrypted Isar vault, biometric unlock, screenshot
protection (`FLAG_SECURE`), encrypted `.firewood` backup/restore, an on-device
security advisor, and Bluetooth P2P vault sharing (native Kotlin BLE transport,
`P2pSharingScreen` under Settings).

## Layout

| Path | Contents |
|---|---|
| `lib/` | app code (screens, services, database, theme, widgets) |
| `android/` | Android platform: signing (ADR-002), R8 rules, native security bridge (`net.firewood.app.security`) |
| `ios/` | iOS platform |
| `assets/` | 3D icon cutouts, fonts |
| `test/` | unit + widget tests (`dart_test.yaml` pins concurrency for Argon2id) |

## Develop

```bash
flutter pub get
flutter analyze
flutter test
```

## Release

Build, sign, publish and the update manifest are handled by the
**firewood-release** toolchain (`tool/deploy.sh`, `tool/release.sh`,
`tool/pipeline`). See `firewood-release/docs/play-store-readiness.md`.

The version in `pubspec.yaml` (`X.Y.Z+N`) is the single source of truth for
`versionName` and `versionCode`.

## Related repositories

`firewood-core` (shared crypto/format), `firewood-desktop`, `firewood-web`,
`firewood-release`. See `firewood-release/docs/repository-map.md`.
