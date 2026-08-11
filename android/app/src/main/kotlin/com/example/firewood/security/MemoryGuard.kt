package com.example.firewood.security

import java.security.SecureRandom
import java.util.Arrays

/**
 * Memory sanitization helpers for sensitive data.
 *
 * Dart's SecretKey is GC-managed with no deterministic zeroization.
 * This Kotlin layer provides explicit buffer clearing for any sensitive
 * material crossing the Flutter-Native boundary (biometric auth, clipboard,
 * password-derived key material).
 *
 * Design rule: every method that handles sensitive byte[] or CharArray MUST
 * either zeroize it or return it via a single-owner path that guarantees
 * eventual zeroization.
 */
object MemoryGuard {

    private val secureRandom = SecureRandom()

    /**
     * Zero-fills a ByteArray in-place and then erases the reference.
     * Call site is responsible for ensuring no further reads of [data]
     * after this call – the variable should be reassigned to empty.
     */
    fun zeroize(data: ByteArray): ByteArray {
        Arrays.fill(data, 0.toByte())
        return ByteArray(0)
    }

    /**
     * Zero-fills a CharArray in-place (for password buffers).
     * Unlike String (immutable, interned, lives until GC),
     * CharArray can be deterministically cleared.
     */
    fun zeroize(data: CharArray): CharArray {
        Arrays.fill(data, '\u0000')
        return CharArray(0)
    }

    /**
     * Overwrites [data] with cryptographically random bytes before zeroing.
     * Defeats cold-boot attacks and memory forensics where remnant charges
     * in RAM can reveal prior bit patterns even after zeroing.
     */
    fun randomizeThenZeroize(data: ByteArray) {
        secureRandom.nextBytes(data)
        Arrays.fill(data, 0.toByte())
    }

    /**
     * Securely compares two ByteArrays in constant time.
     * Use for verifying derived keys, auth tokens, or MACs without
     * leaking timing side-channels.
     */
    fun constantTimeEquals(a: ByteArray, b: ByteArray): Boolean {
        if (a.size != b.size) return false
        var result = 0
        for (i in a.indices) {
            result = result or (a[i].toInt() xor b[i].toInt())
        }
        return result == 0
    }

    /**
     * Creates a ByteArray from [password] via UTF-8 encoding that must be
     * zeroized after use. Never use String for password handling in native code
     * – String is immutable and lives in the string pool until GC.
     */
    fun passwordToByteArray(password: String): ByteArray {
        val bytes = password.toByteArray(Charsets.UTF_8)
        // Caller MUST call zeroize() on the returned array after use
        return bytes
    }
}
