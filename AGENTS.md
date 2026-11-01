# AGENTS.md — `firewood-mobile` Coding & Architecture Guide

This document defines the strict rules for writing **consistent, simple, and reusable** Flutter/Dart code in `firewood-mobile` (`net.firewood.app`). Follow these conventions before creating new files, writing UI components, or modifying services.

---

## 1. Core Principles: Consistency, Simplicity & Reusability

1. **Reuse Before Creating:** Always check `lib/theme/` and `lib/widgets/` before writing new UI widgets, buttons, dialogs, toasts, icons, or layout tokens.
2. **Keep Code Simple (KISS):** Write flat, readable Dart 3.4+ code. Avoid over-abstraction, speculative wrappers, or unused packages (note: code-generated `@riverpod` is **not** used in this project; use standard `flutter_riverpod` providers).
3. **Single Source of Truth:** Colors, spacing, border radii, typography, icons, and cryptographic primitives each have a single canonical module. Never hardcode duplicates in screen files.
4. **Strict Layer Separation:** Keep UI (`screens/`, `widgets/`), State (`providers/`), Domain/Platform Services (`services/`, `security/`), and Persistence (`database/`) cleanly separated.

---

## 2. Project Structure & Responsibilities

```text
firewood-mobile/lib/
├── main.dart                  # Entry point, ProviderScope, initial bootstrapping
├── app.dart                   # Root FirewoodApp, lifecycle listener, _AuthGate
├── database/                  # Isar singleton (IsarService) and schemas (Vault, SecureItem, BurnerHash)
├── models/                    # Pure data types and enums (e.g., ItemType)
├── providers/                 # Riverpod providers (authProvider, lock settings, biometric state)
├── security/                  # CryptoService (Argon2id, HKDF-SHA256, XChaCha20-Poly1305)
├── services/                  # Stateless or singleton business/platform services (VaultService, ItemService, LockService, etc.)
├── theme/                     # Design system tokens, colors, icons, buttons, and feedback dialogs/toasts
├── widgets/                   # Reusable, composable UI widgets shared across screens
└── screens/                   # Top-level route screens composed from widgets/ and theme/
```

### Placement Rules
- **If a UI element is used in ≥ 2 screens** (or exceeds ~80 lines inside a screen), extract it into a `StatelessWidget` or `StatefulWidget` in `lib/widgets/` (or `lib/theme/` for core primitives).
- **Never put Isar queries, `MethodChannel` calls, or cryptographic operations inside `screens/` or `widgets/`.** Route all data and platform operations through `lib/services/`.

---

## 3. Reusable UI & Design System ("Dark Zinc Technical Vault")

`firewood-mobile` uses a matte dark design system: flat zinc surfaces, thin `1px` borders, zero glow, and dynamic accent colors synced via `AccentColorService`.

### 3.1 Always Use Existing Primitives

| Need | Canonical Component / Token | File |
|---|---|---|
| **Colors & Surfaces** | `AppColors.backgroundZinc`, `surfaceZinc`, `cardZinc`, `borderZinc`, `offWhite`, `textSecondary`, `textMuted`, `orangeAccent`, `roseAccent`, `mintAccent` | `lib/theme/app_theme.dart` |
| **Spacing / Radii / Borders / Type** | `VaultSpacing` (`xs`..`xxxl`), `VaultRadii` (`sm`..`xl`), `VaultBorders`, `VaultTypography` | `lib/theme/vault_design_system.dart` |
| **Icons** | `AppIcon(AppIcons.xyz)` for general UI; `AppInputIcons` for `TextField` prefix/suffix chrome | `lib/theme/app_icons.dart` |
| **Buttons** | `AppButton` with `AppButtonVariant` (`primary`, `danger`, `success`, `secondary`, `soft`, `outline`) | `lib/theme/app_button.dart` |
| **Toasts / Snackbars** | `AppToast.show(context, message: '...', type: ToastType.info)` | `lib/theme/app_feedback.dart` |
| **Confirmation Dialogs** | `AppDialog.showConfirmation(context, title: '...', message: '...', isDanger: ...)` | `lib/theme/app_feedback.dart` |
| **Loading Indicators** | `AppLoader` (inline or `AppLoader.show(context)` / `AppLoader.hide(context)`) | `lib/widgets/app_loader.dart` |
| **Error States** | `AppErrorView(title: '...', error: err, onRetry: _retry)` | `lib/widgets/app_error_view.dart` |
| **App Bars & Cards** | `VaultAppBar`, `VaultSectionLabel`, `VaultMetricCard`, `VaultCategoryCard`, `VaultCredentialTile` | `lib/widgets/vault_components.dart` |

### 3.2 Widget Composition Rules

- **Prefer `StatelessWidget` / `ConsumerWidget` classes over `_build*()` helper methods:** Helper methods retain closure context and prevent Flutter from skipping sub-tree rebuilds. Extract sub-trees into small private `StatelessWidget` classes with `const` constructors.
- **Strict `const` Usage:** Prepend `const` to all immutable widgets, `EdgeInsets`, `SizedBox`, and `TextStyle` declarations.
- **No Raw `SnackBar` or Unstyled `ElevatedButton`:** Always use `AppToast.show`, `AppDialog.showConfirmation`, and `AppButton` so visual styling and haptics remain uniform across the app.
- **Consistent Haptics:** Trigger subtle tactile feedback on primary interactions (`HapticFeedback.lightImpact()` on taps, `HapticFeedback.selectionClick()` on copies/toggles).

```dart
// ❌ BAD: Raw SnackBar, hardcoded hex colors, and custom button containers
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Saved', style: TextStyle(color: Color(0xFFFAFAFA)))),
);

// ✅ GOOD: Reusable design-system primitives
AppToast.show(
  context,
  message: 'Credential saved',
  type: ToastType.success,
);
```

---

## 4. State Management (`flutter_riverpod`)

We use standard `flutter_riverpod` (`Provider`, `StateProvider`, `StateNotifierProvider`) without `riverpod_generator` codegen.

- **`authProvider` is the Single Lock Invariant:**
  - `authProvider` (`StateProvider<SecretKey?>`) holds the decrypted vault key **in RAM only**.
  - `ref.watch(authProvider) != null` means unlocked; `null` means locked.
  - Every lock trigger (idle timeout, background lock, manual lock, duress burner) sets `authProvider` to `null`, which automatically clears autofill and pops all routes back to the lock screen (`app.dart`).
- **`ref.watch` vs `ref.read`:**
  - Use `ref.watch(provider)` inside `build()` so widgets reactively rebuild.
  - Use `ref.read(provider)` inside callbacks (`onPressed`, `initState`) where reactive subscription is undesirable.
- **Avoid `FutureBuilder` Flicker:**
  - Never instantiate a new `Future` inline inside `build()` (e.g., `FutureBuilder(future: _service.load())`).
  - Cache the `Future` in a state field (`_loadFuture ??= _service.load()`) and refresh it by resetting `_loadFuture = null` inside `setState(() {})`.

```dart
// ❌ BAD: Creates a new Future on every rebuild, flashing the loading spinner
@override
Widget build(BuildContext context) {
  return FutureBuilder<List<DecryptedItem>>(
    future: _itemService.getAllItems(key),
    builder: (context, snapshot) => ...,
  );
}

// ✅ GOOD: Cached Future with explicit refresh method
Future<List<DecryptedItem>>? _itemsFuture;

void _refreshItems(SecretKey key) {
  if (!mounted) return;
  setState(() {
    _itemsFuture = _itemService.getAllItems(key);
  });
}
```

---

## 5. Lifecycle, Async Safety & Memory Management

- **Mandatory `mounted` Guards:** Every `async` method in a `State` or `ConsumerState` **must** check `if (!mounted) return;` after every `await` before calling `setState`, `Navigator.of(context)`, or `AppToast.show(context, ...)`.
- **Dispose All Controllers & Subscriptions:**
  - Every `TextEditingController`, `PageController`, `ScrollController`, `AnimationController`, `FocusNode`, `Timer`, and `StreamSubscription` created in a widget or service must be disposed/cancelled in `dispose()`.
  - Remove listeners (e.g., `AccentColorService.currentColor.removeListener(...)`) and clear `MethodChannel` handlers in `dispose()`.
- **System Dialogs & Foreground Flows:**
  - When launching an OS dialog (file picker, permission prompt, share sheet) that temporarily takes window focus, wrap the async call with `LockService.beginForegroundFlow()` and `LockService.endForegroundFlow()` in a `try / finally` block so the app does not spuriously auto-lock mid-flow.

```dart
LockService.beginForegroundFlow();
try {
  final result = await FilePicker.platform.pickFiles();
  if (!mounted || result == null) return;
  // handle file...
} finally {
  LockService.endForegroundFlow();
}
```

---

## 6. Security & Cryptographic Invariants

When writing or modifying services and screens in `firewood-mobile`, never violate these security rules:

1. **Zero-Knowledge Metadata (V-009):** Item `title` and `type` must live inside the encrypted JSON payload (`__title`, `__type`), never in plaintext Isar columns (`SecureItem.title` and `SecureItem.type` must remain `''`).
2. **Subkey & AAD Binding (V-028):** Never encrypt with a raw master key. Always use `CryptoService.deriveSubkey(key, purpose)` and bind item ciphertexts to their `itemId` using `aad: CryptoService.itemAad(itemId)`.
3. **Secure Clipboard (REQ-CLIP-01 / V-017):** Never call `Clipboard.setData` directly for credentials, tokens, or diagnostics. Always route copies through `ref.read(lockServiceProvider).copySecret(text)` so Android marks the clip `EXTRA_IS_SENSITIVE` and clears it after the 30-second TTL.
4. **Typed Domain Exceptions:** Throw and catch explicit domain exceptions (`VaultException`, `ItemException`, `SecretBoxAuthenticationError`) in services rather than returning raw strings or swallowing errors silently.
5. **RAM-Only Secrets:** Never log passwords, `SecretKey` bytes, nonces, or decrypted fields via `print` or `debugPrint`.

---

## 7. Code Style, Linting & Testing Standards

- **Modern Dart 3.4+ Idioms:**
  - Use records (e.g., `({List<int> ciphertext, List<int> nonce})`) for lightweight multi-value returns instead of ad-hoc wrapper classes.
  - Use exhaustive `switch` expressions on enums (`ItemType`, `AppLifecycleState`, `AppButtonVariant`).
  - Use `.withValues(alpha: ...)` instead of deprecated `.withOpacity(...)` in new code.
- **Zero Analyzer Warnings:**
  - Run `flutter analyze` before completing any task. All code must pass `flutter_lints` with zero warnings or errors.
- **Automated Testing:**
  - Run `flutter test` (note: `dart_test.yaml` caps concurrency for Argon2id memory safety).
  - Add or update unit tests in `test/` for service/crypto changes and widget tests for UI/navigation changes.
