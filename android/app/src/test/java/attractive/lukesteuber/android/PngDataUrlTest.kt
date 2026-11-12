/*
 * File Purpose: Checks which exported images the Android shell accepts for saving.
 * Primary Components: PngDataUrlTest.
 * Inputs/Outputs: Feeds data URLs to PngDataUrl and checks the decoded bytes.
 */

package attractive.lukesteuber.android

import java.util.Base64
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PngDataUrlTest {
    private val png = byteArrayOf(
        0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13,
    )

    private fun dataUrl(bytes: ByteArray, type: String = "image/png") =
        "data:$type;base64," + Base64.getEncoder().encodeToString(bytes)

    @Test
    fun decodesPngDataUrl() {
        assertArrayEquals(png, PngDataUrl.decode(dataUrl(png)))
    }

    @Test
    fun rejectsOtherUrlsAndTypes() {
        assertNull(PngDataUrl.decode(null))
        assertNull(PngDataUrl.decode("https://example.com/a.png"))
        assertNull(PngDataUrl.decode("blob:file:///1234"))
        assertNull(PngDataUrl.decode(dataUrl(png, "text/html")))
        assertNull(PngDataUrl.decode("data:image/png,plain"))
    }

    @Test
    fun rejectsBytesThatAreNotPng() {
        assertNull(PngDataUrl.decode(dataUrl("<html></html>".toByteArray())))
        assertNull(PngDataUrl.decode("data:image/png;base64,***"))
        assertNull(PngDataUrl.decode(dataUrl(png.copyOf(8))))
    }
}
