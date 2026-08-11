package com.example.firewood.security

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Encrypted SharedPreferences for Firewood settings.
 *
 * Replaces raw SharedPreferences usage in the Flutter layer for sensitive
 * keys such as:
 *  - `biometric_master_password` → replaced by Keystore-wrapped blob
 *  - `peer_alias`, `device_identity` → should be encrypted at rest
 *
 * Uses AndroidX Security Crypto library:
 *  - AES-256-GCM for values
 *  - MasterKey stored in Android Keystore
 */
object SecurePreferences {

    private const val PREFERENCES_NAME = "firewood_secure_prefs"
    private const val KEY_VAULT_WRAPPED_PASSWORD = "vault_wrapped_password_v1"
    private const val KEY_BIOMETRIC_ENABLED = "biometric_enabled"
    private const val KEY_FAILED_ATTEMPT_COUNT = "failed_unlock_attempts"
    private const val KEY_LAST_FAILED_ATTEMPT_TIME = "last_failed_attempt_epoch_ms"
    private const val KEY_LOCKOUT_UNTIL_TIME = "lockout_until_epoch_ms"

    /**
     * Returns an EncryptedSharedPreferences instance.
     * The MasterKey is AES-256 in Android Keystore (hardware-backed on supported devices).
     */
    fun getInstance(context: Context): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        return EncryptedSharedPreferences.create(
            context,
            PREFERENCES_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    // --- Biometric-related helpers ---

    /**
     * Stores the Keystore-wrapped master password blob.
     * The actual master password is never written to disk in plaintext.
     */
    fun storeWrappedPassword(context: Context, wrappedBlob: ByteArray) {
        getInstance(context)
            .edit()
            .putString(KEY_VAULT_WRAPPED_PASSWORD,
                android.util.Base64.encodeToString(wrappedBlob, android.util.Base64.NO_WRAP))
            .apply()
    }

    /**
     * Reads the Keystore-wrapped master password blob.
     * Returns null if biometric unlock was never set up.
     */
    fun getWrappedPassword(context: Context): ByteArray? {
        val b64 = getInstance(context).getString(KEY_VAULT_WRAPPED_PASSWORD, null)
        return b64?.let { android.util.Base64.decode(it, android.util.Base64.NO_WRAP) }
    }

    fun clearWrappedPassword(context: Context) {
        getInstance(context).edit().remove(KEY_VAULT_WRAPPED_PASSWORD).apply()
    }

    fun setBiometricEnabled(context: Context, enabled: Boolean) {
        getInstance(context).edit().putBoolean(KEY_BIOMETRIC_ENABLED, enabled).apply()
    }

    fun isBiometricEnabled(context: Context): Boolean {
        return getInstance(context).getBoolean(KEY_BIOMETRIC_ENABLED, false)
    }

    // --- Rate limiting helpers ---

    /**
     * Records a failed unlock attempt. Returns the current count AFTER incrementing.
     */
    fun recordFailedAttempt(context: Context): Int {
        val prefs = getInstance(context)
        val count = prefs.getInt(KEY_FAILED_ATTEMPT_COUNT, 0) + 1
        prefs.edit()
            .putInt(KEY_FAILED_ATTEMPT_COUNT, count)
            .putLong(KEY_LAST_FAILED_ATTEMPT_TIME, System.currentTimeMillis())
            .apply()

        // Calculate exponential backoff lockout
        if (count >= 5) {
            val delaySeconds = calculateBackoffSeconds(count)
            val lockoutUntil = System.currentTimeMillis() + delaySeconds * 1000L
            prefs.edit()
                .putLong(KEY_LOCKOUT_UNTIL_TIME, lockoutUntil)
                .apply()
        }

        return count
    }

    /**
     * Returns the number of milliseconds the user must wait before the next
     * unlock attempt. Returns 0 if no lockout is active.
     */
    fun getLockoutRemainingMs(context: Context): Long {
        val prefs = getInstance(context)
        val lockoutUntil = prefs.getLong(KEY_LOCKOUT_UNTIL_TIME, 0L)
        if (lockoutUntil == 0L) return 0L

        val remaining = lockoutUntil - System.currentTimeMillis()
        return if (remaining > 0) remaining else {
            // Lockout expired – reset but keep attempt count
            prefs.edit().putLong(KEY_LOCKOUT_UNTIL_TIME, 0L).apply()
            0L
        }
    }

    /**
     * Exponentially increasing backoff:
     *   5 failures →  5 seconds
     *   6 failures →  10 seconds
     *   7 failures →  20 seconds
     *   8 failures →  40 seconds
     *   9 failures →  80 seconds
     *  10+ failures → 300 seconds (5 minutes)
     */
    private fun calculateBackoffSeconds(failedAttempts: Int): Long {
        return when {
            failedAttempts >= 10 -> 300L
            failedAttempts >= 5 -> (5L shl (failedAttempts - 5)).coerceAtMost(300L)
            else -> 0L
        }
    }

    /**
     * Resets the failed attempt counter (on successful unlock).
     */
    fun resetFailedAttempts(context: Context) {
        getInstance(context).edit()
            .putInt(KEY_FAILED_ATTEMPT_COUNT, 0)
            .putLong(KEY_LAST_FAILED_ATTEMPT_TIME, 0L)
            .putLong(KEY_LOCKOUT_UNTIL_TIME, 0L)
            .apply()
    }

    /**
     * Returns the current failed attempt count.
     */
    fun getFailedAttemptCount(context: Context): Int {
        return getInstance(context).getInt(KEY_FAILED_ATTEMPT_COUNT, 0)
    }
}
