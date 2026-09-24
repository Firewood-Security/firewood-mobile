# Module Catalog

Per-file API surface (verified by full-file reads of crypto/vault/item/backup/database/providers; headers + grep for the remainder).

| Module | Key classes / functions | Notes |
|---|---|---|
| `main.dart` | `main()`, global `FlutterError.onError` + `ErrorWidget.builder` | Inits accent + update checker in try/catch; no vault init (lazy) |
| `app.dart` | `FirewoodApp`, `_AuthGate`, lifecycle `paused→onAppPaused/resumed→onAppResumed` | Pointer-down listener resets idle timer; routes splash/setup/unlock/home |
| `security/crypto_service.dart` | `generateSalt`, `deriveKey`, `deriveSubkey` (unused), `encrypt/decrypt`, `encryptString/decryptString` | Params pinned; MAC appended to ciphertext; short-cipher guard |
| `database/isar_service.dart` | `IsarService.instance` (lazy + busy-wait), `close`, `deleteDatabase` | No `encryptionKey` — deliberate |
| `database/schemas.dart` | `Vault(vaultId,name,salt,verifierToken?,verifierNonce?,isDefault,createdAt)`, `SecureItem(itemId,vaultId,encryptedData,nonce,type,title,updatedAt)`, `BurnerHash(passwordHash,label,createdAt)` | `.g.dart` is codegen, do-not-edit |
| `models/item_type.dart` | `ItemType{login,card,note,identity,developerSecret}`, `label`, `fromString` (lenient) | `developerSecret` shown as "API Key" |
| `providers/auth_provider.dart` | `authProvider`, `isUnlockedProvider`, service providers, `BiometricAuthNotifier` | Raw-password SecureStorage key lives here (`biometric_master_password`) |
| `services/vault_service.dart` | `createVault`, `unlock`, `hasAnyVault`, `burnAllVaults`, `exportVault` (plaintext payload, `vaultVersion 2.0`), `importVaultPayload`, `decryptAndImportVaultItems`; `VaultException` | Burner check advertised in header, implemented in UI + `burner_service` |
| `services/item_service.dart` | `addItem`, `getAllItems` (desc), `updateItem` (merge + fresh nonce), `deleteItem` (no key), `getItem`, `searchItems` (plaintext title); `DecryptedItem`; `ItemException` | Injects `created_at` into encrypted JSON |
| `services/lock_service.dart` | `lockTimeoutOptions`, `onAppPaused/Resumed`, `onUserInteraction`, `scheduleClipboardClear` (30 s), `lockServiceProvider`, `lockTimeoutProvider` (5 m default, **unp persisted**), `autoLockEnabledProvider` | Timer callback nulls `authProvider` |
| `services/backup_service.dart` | `exportVault(password,path?)`, `importVault(path,password,{overwrite,activeVaultKey})`, `BackupData/BackupItem` (dual snake/camel JSON), `BackupException` | Outer `salt\|\|nonce\|\|ct` file; strict `1.0.0` check |
| `services/generator_service.dart` | `generatePassword` (4–128, class guarantees, similar/ambiguous filters), `generatePIN`, `generatePassphrase` (~200-word list), `evaluateStrength` (entropy + penalties), Base32, `generateTOTP`/`getTOTPRemainingSeconds`/`generateTOTPSecret`/`isValidTOTPSecret` | TOTP fns have no UI callers |
| `services/biometric_service.dart` | `BiometricAuthService.authenticateUser` (`biometricOnly:false` → device PIN fallback) | Gate only; fail-closed except missing hardware → `true` |
| `services/native_security_bridge.dart` | `createWrappingKey`, `wrap/unwrapMasterPassword`, `has/deleteWrappingKey`, `recordFailedUnlockAttempt`, `getLockoutStatus`, `resetFailedAttempts`, `enable/disableSecureFlag`, `auditEnvironment`, `clearClipboard` (no Dart caller) | Migration note: Keystore replaces raw SecureStorage |
| `services/burner_service.dart` | Burner-hash CRUD + `isBurnerPassword` + `executeBurn` | Min 6-char burner (vs 8-char master) |
| `services/mini_ml_advisor.dart` | `SecurityAdvisorEngine.analyze` (unified engine: finding groups + metrics + 0–100 score, worst-first) + `MiniMLSecurityAdvisor.evaluateOccasionalTip` (72 h cooldown via prefs) | Single source of truth (folded in the former decision-tree classifier, analytics counters, and issue collector; `analytics_service.dart` removed). In-memory `DecryptedItem`s; no persistence/network. No "compromised" metric (no on-device breach corpus) |
| `services/accent_color_service.dart` | 5 presets, `currentColor` ValueNotifier, prefs + SecureStorage fallback init | Imported by theme (coupling) |
| `services/app_version_service.dart` | Centralized version metadata | — |
| `services/update_service.dart` | `initUpdateChecker`, per-platform `GET /update`, `hasUpdateAvailable` | Errors swallowed; only status code logged |
| `screens/splash_screen.dart` | 3 s cinematic splash | Pure UI |
| `screens/vault_setup_screen.dart` | Create form + strength meter + backup-import path (`overwrite:true`) | Auto-login post-create |
| `screens/vault_unlock_screen.dart` | Lockout pre-check → burner check → `unlock` → re-wrap → clear/reset | Biometric auto-trigger; legacy fallback |
| `screens/home_screen.dart` | 4-tab `IndexedStack`, dashboard, vault list (search/filter/sort/grid), generator tab, FAB + action sheet | Largest file; private cards/tiles |
| `screens/item_detail_screen.dart` | Per-type forms, payload build, save/delete, generator sheet, formatters | Canonical field-key definitions |
| `screens/credential_view_screen.dart` | Biometric/password gate → masked details → copy/edit/ID-image viewer | Password fallback re-derives via `unlock` |
| `screens/settings_screen.dart` | Appearance, auto-lock, screenshots, `.env` export, burner mgmt, auto-backup prefs, export/import, updates, about, delete-vault | Biometric-first + password verify for delete |
| `screens/about_screen.dart` | Info + privacy/license dialogs (`url_launcher`) | No sensitive ops |
| `theme/app_theme.dart` | `AppColors` (zinc + accent-derived + rose/mint/periwinkle), `getDarkTheme(accent)` M3 | `lightTheme => darkTheme` |
| `theme/app_3d_button.dart` | `App3DButton` 7 variants + loading/disabled | Used in 2 screens only |
| `theme/app_icons.dart` | `AppIcons` Hugeicons map + `AppIcon` renderer | — |
| `theme/app_feedback.dart` | `AppToast` (4 types), `AppDialog.showConfirmation` | Dialog confirm button duplicates 3D style inline |
| `widgets/*` (6) | Floating navbar (4 tabs + update badge) · segmented bar (5 types) · strength meter · accent picker · welcome banner · guide modal (v2 pref key) | Navbar hardcodes tabs + `UpdateService`; segmented bar hardcodes `ItemType` |
