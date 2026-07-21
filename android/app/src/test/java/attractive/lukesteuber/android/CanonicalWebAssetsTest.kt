/*
 * File Purpose: Guards the Android package's dependency on Attractive's offline web bundle.
 * Primary Components: Asset inventory and offline entry-point checks.
 * Inputs/Outputs: Reads ../web through a Gradle-injected path and reports contract failures.
 */

package attractive.lukesteuber.android

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CanonicalWebAssetsTest {
    private val webDirectory = File(requireNotNull(System.getProperty("attractive.webDir")))

    @Test
    fun requiredAssetsExist() {
        listOf(
            "index.html",
            "style.css",
            "main.js",
            "attractive-3d.js",
            "vendor/three.min.js",
            "vendor/rough.min.js",
            "vendor/katex.min.js",
            "vendor/katex/katex.min.css",
        ).forEach { relativePath ->
            assertTrue(
                "$relativePath must exist in the offline web bundle",
                webDirectory.resolve(relativePath).isFile,
            )
        }
    }

    @Test
    fun entryPointUsesBundledRelativeAssets() {
        val html = webDirectory.resolve("index.html").readText()

        assertTrue(html.contains("""src="vendor/three.min.js""""))
        assertTrue(html.contains("""src="vendor/rough.min.js""""))
        assertTrue(html.contains("""src="vendor/katex.min.js""""))
        assertTrue(html.contains("""href="vendor/katex/katex.min.css""""))
        assertTrue(html.contains("""src="main.js""""))
        assertFalse(html.contains("cdn.jsdelivr.net"))
        assertFalse(html.contains("fonts.googleapis.com"))
        assertFalse(html.contains("stats.dr.eamer.dev"))
    }
}
