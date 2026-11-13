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
            "compact-window.css",
            "main.js",
            "attractive-3d.js",
            "vendor/three.min.js",
            "vendor/rough.min.js",
            "vendor/katex.min.js",
            "vendor/katex/katex.min.css",
            "third-party-notices.html",
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
        assertTrue(html.contains("""href="compact-window.css""""))
        assertFalse(html.contains("cdn.jsdelivr.net"))
        assertFalse(html.contains("fonts.googleapis.com"))
        assertFalse(html.contains("stats.dr.eamer.dev"))
    }

    @Test
    fun aboutLinksToNoticesForEveryBundledLibrary() {
        val html = webDirectory.resolve("index.html").readText()
        assertTrue(html.contains("""href="third-party-notices.html""""))

        val notices = webDirectory.resolve("third-party-notices.html").readText()
        listOf(
            "three.js 0.149.0",
            "Copyright © 2010-2023 three.js authors",
            "Rough.js 4.6.6",
            "Copyright (c) 2019 Preet Shihn",
            "KaTeX 0.16.11",
            "Khan Academy and other contributors",
            "SIL OPEN FONT LICENSE Version 1.1",
            "Reserved Font Names KaTeX_AMS",
        ).forEach { expected ->
            assertTrue("notices page must contain: $expected", notices.contains(expected))
        }
        assertFalse("notices page must load nothing remote", notices.contains("<script src="))
    }

    @Test
    fun threeDCanvasIsPinnedToTheViewport() {
        // Without a CSS size the WebGL canvas is laid out at its drawing-buffer size,
        // which is devicePixelRatio times larger than the screen on phones and tablets.
        val threeD = webDirectory.resolve("attractive-3d.js").readText()
        assertTrue(threeD.contains("#canvas3d{width:100%;height:100%;"))
    }

    @Test
    fun appTextMakesNoMeasuredOrLiveDataClaims() {
        val text = listOf("index.html", "main.js").joinToString("\n") {
            webDirectory.resolve(it).readText()
        }
        listOf("real-world data", "Real-world data", "1960-2024", "Live Audio", "Live microphone", "26 Systems")
            .forEach { claim -> assertFalse("web bundle must not say: $claim", text.contains(claim)) }
    }
}
