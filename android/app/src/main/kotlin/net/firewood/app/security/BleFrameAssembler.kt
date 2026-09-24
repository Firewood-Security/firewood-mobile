package net.firewood.app.security

import java.io.ByteArrayOutputStream

/**
 * Reassembles a framed Firewood BLE transfer from fixed-size ATT chunks.
 *
 * Frame layout (identical to the Dart `BleFrame` and the desktop transport):
 * ```
 *   [0..3]  u32 big-endian length of the payload that follows the name
 *   [4..5]  u16 big-endian file-name length
 *   [6..]   UTF-8 file name, immediately followed by the payload
 * ```
 *
 * A vault is far larger than one ATT packet (20 bytes by default, at most
 * MTU-3), so the sender writes the frame in chunks and the receiver buffers them
 * until the declared length is satisfied, then emits the frame exactly once.
 *
 * This class deliberately has no Android dependencies so it can be unit tested
 * on the JVM.
 */
class BleFrameAssembler(private val maxFrameBytes: Int = DEFAULT_MAX_FRAME_BYTES) {

    private val buffer = ByteArrayOutputStream()
    private var expected: Int? = null

    /** Number of bytes buffered so far. */
    val byteCount: Int get() = buffer.size()

    /**
     * Feeds the next [chunk] of the stream.
     *
     * @return the complete frame once every declared byte has arrived, otherwise
     *   null (more chunks are expected).
     * @throws FrameFormatException when the stream cannot be a valid frame
     *   (impossible declared length, or more than [maxFrameBytes] buffered).
     *   The assembler resets itself before throwing.
     */
    fun accept(chunk: ByteArray): ByteArray? {
        if (chunk.isNotEmpty()) {
            buffer.write(chunk, 0, chunk.size)
        }

        if (buffer.size() > maxFrameBytes) {
            reset()
            throw FrameFormatException("Transfer exceeds $maxFrameBytes bytes")
        }

        val bytes = buffer.toByteArray()

        // Learn the declared length once the header has fully arrived. Never
        // memoise "header incomplete" – later chunks still complete it.
        var frameLength = expected
        if (frameLength == null) {
            frameLength = declaredLength(bytes) ?: return null
            if (frameLength <= 0 || frameLength > maxFrameBytes) {
                // Impossible or oversized frame: reject it up front rather than
                // buffering megabytes on behalf of a bad peer.
                reset()
                throw FrameFormatException("Declared frame length $frameLength is out of range")
            }
            expected = frameLength
        }

        if (bytes.size < frameLength) return null

        val frame = bytes.copyOfRange(0, frameLength)
        reset()
        return frame
    }

    /** Drops any partial frame (disconnect, cancellation, new transfer). */
    fun reset() {
        buffer.reset()
        expected = null
    }

    companion object {
        const val HEADER_LENGTH = 6
        const val DEFAULT_MAX_FRAME_BYTES = 8 * 1024 * 1024

        /**
         * Total frame length declared by the header at [offset], or null while
         * the 6 header bytes have not all arrived.
         */
        fun declaredLength(bytes: ByteArray, offset: Int = 0): Int? {
            if (bytes.size - offset < HEADER_LENGTH) return null
            val payloadLength = u32(bytes, offset)
            val nameLength = u16(bytes, offset + 4)
            val total = HEADER_LENGTH.toLong() + nameLength + payloadLength
            if (total > Int.MAX_VALUE) return -1
            return total.toInt()
        }

        private fun u16(bytes: ByteArray, offset: Int): Long =
            (((bytes[offset].toInt() and 0xFF) shl 8) or
                    (bytes[offset + 1].toInt() and 0xFF)).toLong()

        private fun u32(bytes: ByteArray, offset: Int): Long =
            ((bytes[offset].toLong() and 0xFF) shl 24) or
                    ((bytes[offset + 1].toLong() and 0xFF) shl 16) or
                    ((bytes[offset + 2].toLong() and 0xFF) shl 8) or
                    (bytes[offset + 3].toLong() and 0xFF)
    }
}

class FrameFormatException(message: String) : Exception(message)
