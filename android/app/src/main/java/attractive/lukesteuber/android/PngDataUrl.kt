/*
 * File Purpose: Decodes the PNG the web visualizer hands over when "Export as PNG" is used.
 * Primary Components: PngDataUrl.
 * Inputs/Outputs: Accepts a data:image/png;base64 URL; returns PNG bytes or null.
 */

package attractive.lukesteuber.android

import java.util.Base64

internal object PngDataUrl {
    private const val PREFIX = "data:image/png;base64,"
    private val PNG_SIGNATURE = byteArrayOf(
        0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    )

    /** Returns the image bytes, or null when the URL is not a base64 PNG data URL. */
    fun decode(url: String?): ByteArray? {
        if (url == null || !url.startsWith(PREFIX, ignoreCase = true)) return null
        val bytes = runCatching {
            Base64.getMimeDecoder().decode(url.substring(PREFIX.length))
        }.getOrNull() ?: return null
        if (bytes.size <= PNG_SIGNATURE.size) return null
        for (index in PNG_SIGNATURE.indices) {
            if (bytes[index] != PNG_SIGNATURE[index]) return null
        }
        return bytes
    }
}
