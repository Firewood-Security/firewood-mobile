# Security Policy — Firewood Mobile

Firewood is an offline-first, zero-knowledge password and credential vault. We take security and cryptographic rigor seriously.

---

## Supported Versions

Only the latest release receives security updates. We strongly recommend always running the most recent version:

| Version | Supported |
|---|---|
| `v1.x` (Latest) | ✅ Yes |
| `< v1.0` | ❌ No |

---

## Cryptographic Guarantees & Threat Model

Firewood Mobile is engineered around strict cryptographic invariants:

1. **Zero Knowledge**:
   - The master password is never stored on disk or transferred over any network.
   - Master keys are derived in RAM using **Argon2id** (64 MiB memory, 3 iterations, 4 parallelism lanes).
   - Sensitive credential fields are individually encrypted using **XChaCha20-Poly1305** with unique 24-byte CSPRNG nonces per encryption operation.
2. **Local Isolation**:
   - No remote database, no cloud synchronization, and no third-party telemetry/analytics SDKs exist in the binary.
   - Plaintext data exists solely in volatile memory while the vault is explicitly unlocked.
3. **Hardware-Backed Biometrics**:
   - On Android devices supporting strong biometrics, master credentials can be wrapped in the Android Keystore using hardware-isolated AES-256-GCM keys gated by `BiometricPrompt`.

---

## Reporting a Vulnerability

If you discover a security vulnerability or cryptographic flaw in Firewood Mobile, please report it **responsibly and privately**.

### Disclosure Channels
- **Email**: Send vulnerability reports to `security@firewood.local` (or via our [Web Contact Portal](https://firewoodsec.yahyaoncloud.com/contact/)).
- **Subject Line**: `[SECURITY VULNERABILITY] Firewood Mobile — <Brief Summary>`

Please include:
- A detailed description of the vulnerability.
- Steps to reproduce or proof-of-concept code.
- Potential impact and affected versions.
- (Optional) Suggested remediation or patch.

### Our Commitment
- We will acknowledge receipt of your report within **48 hours**.
- We will provide an assessment and timeline for a patch.
- We will notify you once the fix has been developed, tested, and released.
- We ask that you give us reasonable time to release a patch before disclosing details publicly.

Thank you for helping keep Firewood users secure!
