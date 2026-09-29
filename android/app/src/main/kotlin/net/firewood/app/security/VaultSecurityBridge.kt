package net.firewood.app.security

import android.app.Activity
import android.content.Context
import kotlinx.coroutines.*
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Top-level vault security orchestrator for the Android layer.
 *
 * Responsibilities:
 *  1. Biometric lifecycle – create, bind, unwrap Keystore keys
 *  2. Unlock rate limiting with exponential backoff
 *  3. Auto-lock scheduling to complement Flutter's LockService
 *  4. Environment integrity monitoring
 *  5. Clipboard auto-clear scheduling
 *
 * This is the single entry point Flutter calls through MethodChannel.
 * All other security classes (KeystoreManager, SecurePreferences, MemoryGuard)
 * are orchestrated through this bridge, never called directly from Flutter.
 *
 * Design invariants:
 *  - No raw password persisted anywhere on disk or in SharedPreferences.
 *  - All sensitive byte buffers are zeroized after use via MemoryGuard.
 *  - Rate-limiting state is stored in EncryptedSharedPreferences to prevent
 *    tampering by clearing app data.
 */
class VaultSecurityBridge(
    private val context: Context,
    private val activity: Activity
) {
    private val keystoreManager = SecureKeystoreManager()
    private val scope = CoroutineScope(
        Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "firewood-security").apply {
                isDaemon = true
            }
        }.asCoroutineDispatcher() + SupervisorJob()
    )

    private var clipboardClearJob: Job? = null

    // --- Biometric Key Management ---

    /**
     * Enables biometric vault unlock using Android Keystore key wrapping.
     *
     * Flow:
     *  1. Create AES-256-GCM key in Keystore (bound to biometric + credential)
     *  2. Encrypt [masterPassword] with this key
     *  3. Store encrypted blob in EncryptedSharedPreferences
     *  4. Zeroize all intermediate plaintext buffers
     *
     * After this call, the master password is available via [unwrapMasterPassword]
     * which requires biometric authentication enforced by Keystore.
     */
    fun enableBiometricUnlock(masterPassword: String): Result<Unit> {
        return runCatching {
            // 1. Create Keystore wrapping key (hardware backing is
            // device-dependent and UNVERIFIED per-device — see ADR-003)
            keystoreManager.createWrappingKey()

            // 2. Wrap master password
            val passwordBytes = masterPassword.toByteArray(Charsets.UTF_8)
            try {
                val wrappedBlob = keystoreManager.wrapData(passwordBytes)
                SecurePreferences.storeWrappedPassword(context, wrappedBlob)
                SecurePreferences.setBiometricEnabled(context, true)
            } finally {
                MemoryGuard.randomizeThenZeroize(passwordBytes)
            }
        }
    }

    /**
     * Retrieves the master password via biometric-authenticated Keystore decryption.
     *
     * Caller MUST NOT cache or persist the returned password.
     * The password should be used to derive the SecretKey in Flutter
     * and discarded immediately.
     *
     * @throws SecurityException if biometric auth fails or times out
     * @throws IllegalStateException if biometric unlock was never set up
     */
    fun unwrapMasterPassword(): Result<String> {
        return runCatching {
            val wrappedBlob = SecurePreferences.getWrappedPassword(context)
                ?: throw IllegalStateException("Biometric unlock not set up – no wrapped password found")

            val decryptedBytes = keystoreManager.unwrapData(wrappedBlob)
            try {
                String(decryptedBytes, Charsets.UTF_8)
            } finally {
                MemoryGuard.randomizeThenZeroize(decryptedBytes)
            }
        }
    }

    /**
     * Disables biometric vault unlock.
     *  - Deletes Keystore wrapping key → any existing wrapped blobs become useless
     *  - Clears wrapped password from EncryptedSharedPreferences
     */
    fun disableBiometricUnlock() {
        keystoreManager.deleteWrappingKey()
        SecurePreferences.clearWrappedPassword(context)
        SecurePreferences.setBiometricEnabled(context, false)
        SecurePreferences.resetFailedAttempts(context)
    }

    fun isBiometricUnlockEnabled(): Boolean {
        return keystoreManager.hasWrappingKey() &&
               SecurePreferences.isBiometricEnabled(context)
    }

    // --- Rate-Limited Unlock Attempts ---

    /**
     * Records a failed unlock attempt and returns the lockout state.
     *
     * Exponential backoff schedule:
     *   Attempts 1-4:  No delay (Argon2id is the limiting factor)
     *   Attempt 5:     5 second delay
     *   Attempt 6:    10 second delay
     *   Attempt 7:    20 second delay
     *   Attempt 8:    40 second delay
     *   Attempt 9:    80 second delay
     *   Attempt 10+: 300 second delay (5 minutes)
     *
     * Returns [RateLimitState] with current attempt count and lockout status.
     */
    fun recordFailedUnlock(): RateLimitState {
        val count = SecurePreferences.recordFailedAttempt(context)
        val lockoutMs = SecurePreferences.getLockoutRemainingMs(context)
        return RateLimitState(
            attemptCount = count,
            lockoutRemainingMs = lockoutMs,
            isLockedOut = lockoutMs > 0
        )
    }

    fun getRateLimitState(): RateLimitState {
        val lockoutMs = SecurePreferences.getLockoutRemainingMs(context)
        val count = SecurePreferences.getFailedAttemptCount(context)
        return RateLimitState(
            attemptCount = count,
            lockoutRemainingMs = lockoutMs,
            isLockedOut = lockoutMs > 0
        )
    }

    fun resetRateLimit() {
        SecurePreferences.resetFailedAttempts(context)
    }

    // --- Auto-Lock Scheduling ---

    /**
     * Schedules an auto-lock action after [timeoutSeconds].
     * The lock callback is delivered via MethodChannel to Flutter.
     */
    fun scheduleAutoLock(timeoutSeconds: Long, onLock: () -> Unit) {
        scope.launch {
            delay(timeoutSeconds * 1000L)
            onLock()
        }
    }

    // --- Clipboard Security ---

    /**
     * Schedules clipboard clearing after [delaySeconds].
     * The clipboard content is replaced with an empty string.
     */
    fun scheduleClipboardClear(delaySeconds: Long = 30) {
        clipboardClearJob?.cancel()
        clipboardClearJob = scope.launch {
            delay(delaySeconds * 1000L)
            clearClipboard()
        }
    }

    fun cancelClipboardClear() {
        clipboardClearJob?.cancel()
    }

    fun clearClipboard() {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE)
            as? android.content.ClipboardManager
        clipboard?.setPrimaryClip(
            android.content.ClipData.newPlainText("", "")
        )
    }

    // --- Environment Audit ---

    fun auditEnvironment(): EnvironmentAuditResult {
        return AntiLeakActivityManager.auditEnvironment(context)
    }

    fun onDestroy() {
        scope.cancel()
    }
}

data class RateLimitState(
    val attemptCount: Int,
    val lockoutRemainingMs: Long,
    val isLockedOut: Boolean
)
