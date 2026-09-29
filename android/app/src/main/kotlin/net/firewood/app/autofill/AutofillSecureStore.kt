package net.firewood.app.autofill

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import java.security.UnrecoverableKeyException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

data class AutofillEntry(
    val id: String,
    val title: String,
    val username: String,
    val password: String,
    val url: String,
    val bundle: String? = null
)

/**
 * 100% Offline, Keystore-encrypted store for Firewood fast fill credentials.
 * Operates strictly locally within private app storage with zero network access.
 */
object AutofillSecureStore {
    private const val TAG = "AutofillSecureStore"

    // V-007: v2 keys are user-auth-bound (v1 keys were usable with no
    // authentication at all — retired by getOrCreateKey below).
    private const val KEY_ALIAS = "firewood_autofill_keystore_v2"
    private const val LEGACY_KEY_ALIAS = "firewood_autofill_keystore_v1"
    private const val FILE_NAME = "autofill_vault.enc"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val AES_GCM = "AES/GCM/NoPadding"
    private const val GCM_TAG_LENGTH = 128
    private const val IV_LENGTH = 12

    // V-007: how long a successful user authentication (biometric or device
    // credential) keeps the mirror key usable. Long enough for the picker's
    // prompt→read flow and the post-unlock sync; short enough that a device
    // imaged/extracted minutes after locking cannot decrypt the mirror.
    private const val AUTH_WINDOW_SECONDS = 300

    private fun getOrCreateKey(context: Context): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

        // V-007 migration: v1 keys had no user-auth binding. Retire the key
        // and its ciphertext — the mirror is rebuilt (under the auth-bound
        // key) by the next successful sync.
        if (keyStore.containsAlias(LEGACY_KEY_ALIAS)) {
            try {
                keyStore.deleteEntry(LEGACY_KEY_ALIAS)
            } catch (_: Exception) {}
            try {
                File(context.filesDir, FILE_NAME).delete()
            } catch (_: Exception) {}
        }

        if (keyStore.containsAlias(KEY_ALIAS)) {
            try {
                val entry = keyStore.getEntry(KEY_ALIAS, null) as KeyStore.SecretKeyEntry
                return entry.secretKey
            } catch (e: UnrecoverableKeyException) {
                // Key permanently invalidated / unusable — retire it and mint
                // a fresh auth-bound one below.
                try {
                    keyStore.deleteEntry(KEY_ALIAS)
                } catch (_: Exception) {}
            }
        }

        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE
        )
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            // V-007: the key is only usable within a short window after a real
            // user authentication, and is destroyed when new biometrics are
            // enrolled. Outside the window every operation fails closed.
            .setUserAuthenticationRequired(true)
            .setUserAuthenticationValidityDurationSeconds(AUTH_WINDOW_SECONDS)
            .setInvalidatedByBiometricEnrollment(true)
            .build()
        keyGenerator.init(spec)
        keyGenerator.generateKey()

        val entry = keyStore.getEntry(KEY_ALIAS, null) as KeyStore.SecretKeyEntry
        return entry.secretKey
    }

    @Synchronized
    fun saveCredentials(context: Context, jsonString: String) {
        try {
            val key = getOrCreateKey(context)
            val cipher = Cipher.getInstance(AES_GCM)
            cipher.init(Cipher.ENCRYPT_MODE, key)
            val iv = cipher.iv
            val ciphertext = cipher.doFinal(jsonString.toByteArray(Charsets.UTF_8))

            // Prepend 12-byte IV to ciphertext
            val combined = ByteArray(iv.size + ciphertext.size)
            System.arraycopy(iv, 0, combined, 0, iv.size)
            System.arraycopy(ciphertext, 0, combined, iv.size, ciphertext.size)

            val file = File(context.filesDir, FILE_NAME)
            file.writeBytes(combined)
        } catch (e: Exception) {
            // V-007: outside the auth window (or key invalidated) the mirror
            // cannot be re-encrypted — keep the previous state rather than
            // ever writing plaintext. Next authenticated sync replaces it.
            Log.w(TAG, "autofill mirror sync skipped: ${e.javaClass.simpleName}")
        }
    }

    @Synchronized
    fun getCredentials(context: Context): List<AutofillEntry> {
        val file = File(context.filesDir, FILE_NAME)
        if (!file.exists() || file.length() <= IV_LENGTH) {
            return emptyList()
        }

        try {
            val bytes = file.readBytes()
            val iv = bytes.copyOfRange(0, IV_LENGTH)
            val ciphertext = bytes.copyOfRange(IV_LENGTH, bytes.size)

            val key = getOrCreateKey(context)
            val cipher = Cipher.getInstance(AES_GCM)
            val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
            cipher.init(Cipher.DECRYPT_MODE, key, spec)
            val plaintext = cipher.doFinal(ciphertext)
            val jsonString = String(plaintext, Charsets.UTF_8)

            val list = mutableListOf<AutofillEntry>()
            val array = JSONArray(jsonString)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                list.add(
                    AutofillEntry(
                        id = obj.optString("id"),
                        title = obj.optString("title"),
                        username = obj.optString("username"),
                        password = obj.optString("password"),
                        url = obj.optString("url"),
                        bundle = if (obj.has("bundle")) obj.optString("bundle") else null
                    )
                )
            }
            return list
        } catch (e: KeyPermanentlyInvalidatedException) {
            // V-007: biometrics re-enrolled since this mirror was written —
            // the key is dead, so wipe the now-orphaned ciphertext too.
            clearCredentials(context)
            return emptyList()
        } catch (e: UnrecoverableKeyException) {
            // V-007: same fail-closed treatment for an unusable key.
            clearCredentials(context)
            return emptyList()
        } catch (e: Exception) {
            // Includes UserNotAuthenticatedException (outside the auth window)
            // and GCM tag mismatch — never surface partial data.
            return emptyList()
        }
    }

    /**
     * V-007: whether an auth-encrypted mirror file exists — deliberately does
     * NOT need the key, because the fill-request gate runs before any user
     * authentication (reads themselves stay auth-bound).
     */
    fun hasMirrorData(context: Context): Boolean {
        val file = File(context.filesDir, FILE_NAME)
        return file.exists() && file.length() > IV_LENGTH
    }

    @Synchronized
    fun clearCredentials(context: Context) {
        try {
            val file = File(context.filesDir, FILE_NAME)
            if (file.exists()) {
                file.delete()
            }
        } catch (_: Exception) {}
    }
}
