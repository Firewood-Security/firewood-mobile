# Firewood Mobile — Engineering Runbook

> Living document. Every resolved crash, regression, or operational procedure gets logged here.  
> **Format per entry:** symptom → root cause → fix → verification → prevention.

---

## Table of Contents

1. [Navigation / Back-Press Crash (Stack Overflow)](#1-navigation--back-press-crash-stack-overflow)
2. [Build & Deployment Procedures](#2-build--deployment-procedures)
3. [Debugging Flutter Crashes](#3-debugging-flutter-crashes)
4. [Common Flutter Error Patterns](#4-common-flutter-error-patterns)
5. [Script Reference](#5-script-reference)
6. [Environment Setup](#6-environment-setup)

---

## 1. Navigation / Back-Press Crash (Stack Overflow)

**Date resolved:** 2026-09-28  
**Severity:** 🔴 Critical — app crashes on every back-navigation from any pushed route  
**File:** [`lib/screens/home_screen.dart`](../lib/screens/home_screen.dart#L692-L701)

### Symptom

Navigating from `HomeScreen` to any child screen (Settings, CategoryItems, Search, CredentialView, BundleDetail, ItemDetail) and pressing **Back** causes the app to freeze and then crash with a `StackOverflowError`.

```
FlutterError: Stack Overflow
    at _HomeScreenState._refreshDashboard (home_screen.dart:696)
    at _HomeScreenState._refreshDashboard (home_screen.dart:696)
    at _HomeScreenState._refreshDashboard (home_screen.dart:696)
    ...
```

### Root Cause

`_refreshDashboard()` was written to invalidate the cached `_dashboardFuture` and trigger a rebuild. However, after nulling the future it **called itself recursively** with no base case, causing infinite recursion and an immediate stack overflow.

```dart
// ❌ BROKEN — infinite recursion
void _refreshDashboard() {
  _dashboardFuture = null;
  _refreshDashboard();   // ← calls itself forever → StackOverflowError
}
```

The method was called from `.then((_) => _refreshDashboard())` callbacks attached to every `Navigator.push(...)` future — meaning the crash was guaranteed on every back-press.

### Fix

Replace the recursive call with `setState()`. Setting state with a nulled future is enough: `FutureBuilder` will re-evaluate its `future` argument on the next build and naturally call `_loadDashboardData` again.

```dart
// ✅ FIXED
void _refreshDashboard() {
  if (!mounted) return;          // guard: widget may be disposed
  setState(() {
    _dashboardFuture = null;     // null → FutureBuilder re-runs on next build
  });
}
```

**Key details:**
- The `mounted` guard prevents `setState` being called on a disposed widget (e.g. if the vault locks mid-navigation).
- `FutureBuilder` caches `_dashboardFuture ??= _loadDashboardData(key)` — nulling the field is all that is needed; `setState` ensures the next frame picks it up.

### Verification

1. `flutter analyze` — no new errors.
2. Hot-reload and navigate: Home → Settings → Back → no crash.
3. Home → CategoryItems → Back → dashboard refreshes with latest data.
4. Home → Search → Back → no crash.
5. Lock vault mid-navigation → back-press → lock screen shown, no crash.

### Prevention Checklist

- [ ] Never call a method from inside itself without a **clearly documented base case**.
- [ ] When a method's job is "trigger a rebuild", use `setState` — never recursion.
- [ ] Use `mounted` guards before every `setState` call in async callbacks.
- [ ] Add widget tests for navigation round-trips (`tester.tap(backButton)`).

---

## 2. Build & Deployment Procedures

### 2.1 Build Scripts Location

All operational scripts now live under:

```
firewood-security/
└── scripts/
    ├── build_all.sh          # Full dual build: Android APK + Linux Desktop
    └── watch_and_build.sh    # File watcher: auto-rebuilds on Dart/Kotlin changes
```

> **Note:** Root-level `build_all.sh` and `watch_and_build.sh` remain as legacy entry points but the canonical versions are in `scripts/`.

### 2.2 Running a Build

```bash
# Full release build (Android APK + Linux Desktop + ADB deploy)
cd /home/yahya/SHARED/Projects/firewood-security
./scripts/build_all.sh

# Debug build (faster, no obfuscation, no R8)
./scripts/build_all.sh --debug

# Auto-watch and rebuild on every file save
./scripts/watch_and_build.sh
```

### 2.3 Build Pipeline Steps

| Step | What it does |
|------|-------------|
| **1/4** | `flutter build apk --release --split-per-abi` — builds per-ABI APKs with obfuscation |
| **2/4** | `adb install -r` — installs to connected device, launches the app |
| **3/4** | `flutter build linux --release` — compiles the Linux desktop bundle |
| **4/4** | Copies bundle to `~/.local/opt/firewood` and re-launches the desktop app |

### 2.4 Release Keystore / Signing

If no `android/key.properties` is present and `FIREWOOD_STORE_FILE` is unset, the build auto-falls back to debug-signed APKs (ADR-002 QA policy, V-030). This is intentional for local development; CI/CD must inject the keystore.

---

## 3. Debugging Flutter Crashes

### 3.1 Capturing Logs

```bash
# Real-time device logs (filter to Flutter/Firewood only)
adb logcat -s flutter

# Full device log since last clear
adb logcat -d | grep -E "(flutter|firewood|FATAL|crash)"

# Flutter run with verbose output
flutter run --verbose 2>&1 | tee /tmp/flutter_run.log
```

### 3.2 Analyzing a Dart Stack Trace

1. Collect the `_kDartIsolateSnapshotData` crash from logcat.
2. Run `flutter symbolize`:

```bash
flutter symbolize \
  -i /path/to/stack_trace.txt \
  -d build/app/symbols/app.android-arm64.symbols
```

### 3.3 Common Crash Signals

| Signal | Likely cause |
|--------|-------------|
| `StackOverflowError` | Infinite recursion (see §1) |
| `LateInitializationError` | `late` field accessed before `initState` sets it |
| `setState() called after dispose()` | Missing `mounted` guard in async callback |
| `Null check operator used on null` | Nullable field accessed without null-check |
| `Bad state: Future already completed` | Completer used more than once |
| `type 'Null' is not a subtype of type 'X'` | API returned null where non-null was assumed |

### 3.4 Riverpod Provider Errors

```bash
# Show all provider errors at startup
flutter run --dart-define=RIVERPOD_DEBUG=true
```

Common fixes:
- `ProviderScope` missing → wrap `runApp` in `ProviderScope`.
- Provider read outside build → use `ref.read` not `ref.watch` in callbacks.
- Disposed provider accessed → add `ref.keepAlive()` or restructure.

---

## 4. Common Flutter Error Patterns

### 4.1 `setState` After Dispose

**Symptom:** `setState() or markNeedsBuild() called during build` or `setState called after dispose()`.

```dart
// ❌ BAD
void _asyncCallback() async {
  final result = await someAsyncOp();
  setState(() { _value = result; }); // widget may be disposed by now
}

// ✅ GOOD
void _asyncCallback() async {
  final result = await someAsyncOp();
  if (!mounted) return;
  setState(() { _value = result; });
}
```

### 4.2 Navigator Calls After Dispose

**Symptom:** `Looking up a deactivated widget's ancestor is unsafe`.

```dart
// ❌ BAD — context captured in async gap
Future<void> _navigate() async {
  await someAsync();
  Navigator.of(context).push(...); // context may be stale
}

// ✅ GOOD
Future<void> _navigate() async {
  await someAsync();
  if (!mounted) return;
  Navigator.of(context).push(...);
}
```

### 4.3 FutureBuilder Flicker / Reload Loop

**Symptom:** Spinner flashes on every rebuild; data reloads endlessly.

**Cause:** `FutureBuilder(future: _loadData())` — creating a new Future on every `build()` call.

```dart
// ❌ BAD — new Future created on every build
Widget build(BuildContext context) {
  return FutureBuilder(future: _loadData(), ...);
}

// ✅ GOOD — cache the Future in a field, null it to refresh
Future<Data>? _dataFuture;

Widget build(BuildContext context) {
  return FutureBuilder(
    future: _dataFuture ??= _loadData(),
    ...
  );
}

void refresh() {
  if (!mounted) return;
  setState(() { _dataFuture = null; });
}
```

### 4.4 PageController Accessed After Dispose

**Symptom:** `A PageController was used after being disposed`.

```dart
// ✅ Always check hasClients before PageController operations
if (_pageController.hasClients) {
  _pageController.jumpToPage(index);
}
```

### 4.5 Isar / Database Closed Before Query

**Symptom:** `IsarError: Instance has already been closed`.

**Fix:** Ensure `IsarService` is not re-opened on every call. Use a singleton pattern and await the open future before any read/write.

### 4.6 BLE / Platform Channel Crash on Back-Press

**Symptom:** App crashes when leaving a screen that has an active Bluetooth or platform channel listener.

**Fix:** Cancel all stream subscriptions and method channel handlers in `dispose()`.

```dart
@override
void dispose() {
  _bleScanSubscription?.cancel();
  _methodChannel.setMethodCallHandler(null);
  super.dispose();
}
```

---

## 5. Script Reference

### `scripts/build_all.sh`

| Flag | Effect |
|------|--------|
| *(none)* | Release build: obfuscated APK + Linux bundle |
| `--debug` | Debug build: fast, no obfuscation, no R8 |

**Environment variables:**

| Variable | Effect |
|----------|--------|
| `FIREWOOD_STORE_FILE` | Path to release keystore (enables release signing) |
| `ORG_GRADLE_PROJECT_requireReleaseSigning` | Set to `false` to skip keystore requirement |

### `scripts/watch_and_build.sh`

Watches `firewood-mobile/lib` and `firewood-desktop/lib` for `.dart`, `.kt`, `.xml` changes and re-runs `build_all.sh` automatically. Requires `inotify-tools` (auto-installed if missing).

---

## 6. Environment Setup

### Prerequisites

```bash
# Flutter SDK (verify)
flutter doctor -v

# Android SDK / ADB
adb version

# Dart analyze
flutter analyze

# Dependencies
cd firewood-mobile && flutter pub get
```

### Common Setup Issues

| Issue | Fix |
|-------|-----|
| `flutter: command not found` | Add Flutter `bin/` to `$PATH` |
| `adb: no devices` | Enable USB Debugging + ADB over Wi-Fi on device |
| `Gradle build failed` | Run `./gradlew --stop` then retry |
| `pub get failed` | Check `pubspec.yaml` constraints; run `flutter pub upgrade` |
| `isar_generator not found` | Run `dart run build_runner build --delete-conflicting-outputs` |
| `Kotlin version mismatch` | Sync `kotlin_version` in `android/build.gradle.kts` |

---

*Last updated: 2026-09-28 by Antigravity — Bug #001 (back-press crash) resolved.*
