package net.firewood.app.security

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM tests for the receiver-side chunk reassembly.
 *
 * The frames here are built by an independent encoder (not by the production
 * sender) so these tests actually pin the wire format rather than round-tripping
 * a single implementation against itself.
 */
class BleFrameAssemblerTest {

    /** Reference encoder matching the Dart `BleFrame.encode` layout. */
    private fun frame(name: String, payload: ByteArray): ByteArray {
        val nameBytes = name.toByteArray(Charsets.UTF_8)
        val out = ByteArray(6 + nameBytes.size + payload.size)
        val payloadLength = payload.size
        out[0] = ((payloadLength shr 24) and 0xFF).toByte()
        out[1] = ((payloadLength shr 16) and 0xFF).toByte()
        out[2] = ((payloadLength shr 8) and 0xFF).toByte()
        out[3] = (payloadLength and 0xFF).toByte()
        out[4] = ((nameBytes.size shr 8) and 0xFF).toByte()
        out[5] = (nameBytes.size and 0xFF).toByte()
        nameBytes.copyInto(out, 6)
        payload.copyInto(out, 6 + nameBytes.size)
        return out
    }

    private fun chunk(bytes: ByteArray, size: Int): List<ByteArray> =
        bytes.toList().chunked(size).map { it.toByteArray() }

    @Test
    fun `single chunk returns the whole frame`() {
        val assembler = BleFrameAssembler()
        val bytes = frame("vault.firewood", ByteArray(64) { it.toByte() })

        val result = assembler.accept(bytes)

        assertArrayEquals(bytes, result)
    }

    @Test
    fun `reassembles a frame delivered in 20-byte ATT chunks`() {
        val assembler = BleFrameAssembler()
        val payload = ByteArray(4096) { ((it * 31) % 251).toByte() }
        val bytes = frame("firewood-vault.firewood", payload)
        val chunks = chunk(bytes, 20)
        assertTrue("expected many chunks", chunks.size > 200)

        var completed: ByteArray? = null
        for ((index, piece) in chunks.withIndex()) {
            val result = assembler.accept(piece)
            if (index < chunks.size - 1) {
                assertNull("frame completed early at chunk $index", result)
            } else {
                completed = result
            }
        }

        assertArrayEquals(bytes, completed)
    }

    @Test
    fun `reassembles when chunks split the six-byte header`() {
        val assembler = BleFrameAssembler()
        val bytes = frame("name", byteArrayOf(1, 2, 3))

        var completed: ByteArray? = null
        for (piece in chunk(bytes, 1)) {
            completed = assembler.accept(piece) ?: completed
        }

        assertArrayEquals(bytes, completed)
    }

    @Test
    fun `reassembles at the largest practical MTU chunk size`() {
        val assembler = BleFrameAssembler()
        val bytes = frame("vault.firewood", ByteArray(2048) { (it % 256).toByte() })

        var completed: ByteArray? = null
        for (piece in chunk(bytes, 509)) {
            completed = assembler.accept(piece) ?: completed
        }

        assertArrayEquals(bytes, completed)
    }

    @Test
    fun `ignores bytes past the declared length`() {
        val assembler = BleFrameAssembler()
        val bytes = frame("name", byteArrayOf(9, 9, 9))
        val withTrailer = bytes + byteArrayOf(7, 7, 7, 7)

        val result = assembler.accept(withTrailer)

        assertArrayEquals(bytes, result)
    }

    @Test
    fun `emits once per completed transfer`() {
        val assembler = BleFrameAssembler()
        val bytes = frame("name", byteArrayOf(1, 2, 3, 4))

        assertArrayEquals(bytes, assembler.accept(bytes))
        // A second, identical transfer is legitimate (ATT writes are reliable, so
        // this should not happen in practice) and must be delivered again.
        assertArrayEquals(bytes, assembler.accept(bytes))
    }

    @Test
    fun `reset drops a partial transfer`() {
        val assembler = BleFrameAssembler()
        val bytes = frame("name", ByteArray(32))

        assembler.accept(bytes.copyOfRange(0, 10))
        assembler.reset()
        assertEquals(0, assembler.byteCount)

        // The next full frame must decode cleanly after the stale partial.
        assertArrayEquals(bytes, assembler.accept(bytes))
    }

    @Test
    fun `rejects a frame whose declared length exceeds the cap`() {
        val assembler = BleFrameAssembler(maxFrameBytes = 64)
        // A well-formed header + name that declares a 4 KiB payload.
        val header = frame("name", ByteArray(0))
        header[2] = 0x10 // payload length = 0x1000 = 4096
        val oversized = header + ByteArray(10)

        var thrown = false
        try {
            assembler.accept(oversized)
        } catch (e: FrameFormatException) {
            thrown = true
        }

        assertTrue("expected FrameFormatException", thrown)
        // The assembler must drop the bad frame and be reusable afterwards.
        assertEquals(0, assembler.byteCount)
        val good = frame("ok", byteArrayOf(1, 2))
        assertArrayEquals(good, assembler.accept(good))
    }

    @Test
    fun `declaredLength needs the full header`() {
        val bytes = frame("abc", ByteArray(5))

        assertNull(BleFrameAssembler.declaredLength(bytes.copyOfRange(0, 5)))
        assertEquals(bytes.size, BleFrameAssembler.declaredLength(bytes))
    }
}
