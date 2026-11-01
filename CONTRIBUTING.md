# Contributing to Firewood Mobile

Thank you for your interest in contributing to **Firewood Mobile**! We welcome bug fixes, documentation improvements, test additions, and new features that align with our core mission: **offline-first, zero-knowledge, reliable credential security**.

---

## Code of Conduct

We are committed to providing a welcoming, inclusive, and harassment-free experience for everyone. Please be respectful, constructive, and collaborative in all discussions and code reviews.

---

## Security Invariants (Must Read Before Writing Code)

Before writing or modifying any code in Firewood Mobile, ensure you understand our non-negotiable security boundaries:

1. **Zero Knowledge**:
   - The master password and unencrypted vault master key must **never** touch persistent storage or logs.
   - All credential fields must be encrypted in volatile RAM using `CryptoService` before touching the Isar database.
2. **Lock State Authority (`authProvider`)**:
   - `authProvider` is the single source of truth for the vault state (`null` = locked, non-null = unlocked).
   - Any lock event (manual lock, timer expiry, burner trigger) must nullify `authProvider`.
3. **No Network Telemetry**:
   - Firewood Mobile contains **no analytics, no crash reporting SDKs, and no tracking scripts**. Do not introduce any third-party network telemetry.
4. **Android Protection**:
   - Keep `FLAG_SECURE` support intact.
   - Do not request broad filesystem permissions (`READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE`); always use the Storage Access Framework (SAF).

For detailed technical conventions and design system tokens, see [`AGENTS.md`](AGENTS.md).

---

## Development Workflow

### 1. Setup Local Environment

Ensure you have the required prerequisites:
- [Flutter SDK](https://flutter.dev) (pinned stable `3.47.5+`)
- Android SDK build-tools (API 34+)
- OpenJDK 17 or 21

Clone the repository and install dependencies:
```bash
git clone https://github.com/Firewood-Security/firewood-mobile.git
cd firewood-mobile
flutter pub get
```

### 2. Branching & Commits

- Create a feature or bugfix branch from `main`:
  ```bash
  git checkout -b fix/clipboard-timer
  ```
- Write clear, concise commit messages following standard conventions (e.g., `fix(crypto): prevent nonce reuse on export`, `feat(ui): add search filter chip`).

### 3. Code Standards & Style

- **Formatting**: Always format code using standard Dart tools before committing:
  ```bash
  dart format lib test
  ```
- **Static Analysis**: The code must pass static analysis without warnings or errors:
  ```bash
  flutter analyze lib/ --fatal-warnings --no-fatal-infos
  ```
- **UI & Architecture Guidelines**:
  - Follow the **Dark Zinc Technical Vault** design system in `theme/` and `widgets/`.
  - Prefer using existing reusable components: `AppButton`, `AppToast`, `AppDialog`, `AppLoader`, `AppErrorView`.
  - Keep logic simple (KISS). Avoid premature abstractions.

### 4. Running Tests

Run the full automated test suite:
```bash
flutter test test/ --reporter compact
```
If you add a new service or feature, please include corresponding unit tests under `test/`.

---

## Submitting a Pull Request

1. Push your branch to your GitHub fork:
   ```bash
   git push origin fix/your-bugfix-name
   ```
2. Open a Pull Request targeting `main`.
3. Fill out the PR description template:
   - What problem does this PR solve?
   - How was it tested?
   - Any architectural or security impact?
4. Ensure all CI checks pass.

---

## Reporting Issues

- **Bug Reports**: Please open an issue on GitHub with device details, Android version, steps to reproduce, and logs (redacting any private vault data).
- **Security Vulnerabilities**: Do **not** post security bugs publicly. Follow the reporting guidelines in [`SECURITY.md`](SECURITY.md).
