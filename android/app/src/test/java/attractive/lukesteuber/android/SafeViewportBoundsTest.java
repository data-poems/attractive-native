package attractive.lukesteuber.android;

import org.junit.Test;
import java.util.Arrays;
import java.util.Collections;
import static org.junit.Assert.*;

public class SafeViewportBoundsTest {
    private static SafeViewportBounds.Box full(int width, int height) {
        return new SafeViewportBounds.Box(0, 0, width, height);
    }

    private static void assertBox(int left, int top, int right, int bottom, SafeViewportBounds.Box box) {
        assertEquals(left, box.left);
        assertEquals(top, box.top);
        assertEquals(right, box.right);
        assertEquals(bottom, box.bottom);
    }

    @Test public void reportedCameraStripLeavesFullWidthAboveIt() {
        SafeViewportBounds.Box camera = new SafeViewportBounds.Box(428, 839, 948, 1048);
        SafeViewportBounds.Box safe = SafeViewportBounds.fit(948, 1048, full(948, 1048),
            Collections.singletonList(camera), "samsung", "SM-F776U1");
        assertBox(0, 0, 948, 839, safe);
        assertFalse(safe.overlaps(camera));
    }

    @Test public void compatibilityFrameDoesNotSubtractOutOfViewCameraAgain() {
        // Physical Flip8 Samsung wide frame, measured by the parent workstream.
        SafeViewportBounds.Box safe = SafeViewportBounds.fit(1422, 1259, full(1422, 1259),
            Collections.singletonList(new SafeViewportBounds.Box(642, 1259, 1422, 1572)),
            "samsung", "SM-F776U1");
        assertBox(0, 0, 1422, 1259, safe);
    }

    @Test public void fullCoverWithoutCutoutUsesConservativeMeasuredStrip() {
        assertBox(0, 0, 948, 839, SafeViewportBounds.fit(948, 1048, full(948, 1048),
            Collections.emptyList(), "samsung", "SM-F776U1"));
        assertBox(0, 0, 1422, 1258, SafeViewportBounds.fit(1422, 1572, full(1422, 1572),
            Collections.emptyList(), "Samsung", "sm-f766b"));
    }

    @Test public void modelFallbackNeverTrimsInnerWideOrOlderFlipScreens() {
        int[][] sizes = {{1080, 2520}, {1422, 1259}, {885, 1572}, {1048, 948}};
        for (int[] size : sizes) {
            assertBox(0, 0, size[0], size[1], SafeViewportBounds.fit(size[0], size[1], full(size[0], size[1]),
                Collections.emptyList(), "samsung", "SM-F776U1"));
        }
        for (String model : new String[]{"SM-F741", "Pixel 10", null}) {
            assertBox(0, 0, 948, 1048, SafeViewportBounds.fit(948, 1048, full(948, 1048),
                Collections.emptyList(), "samsung", model));
        }
        assertBox(0, 0, 948, 1048, SafeViewportBounds.fit(948, 1048, full(948, 1048),
            Collections.emptyList(), "other", "SM-F776U1"));
    }

    @Test public void realCutoutWinsOverModelEvenIfItLeavesMoreSpace() {
        assertBox(0, 0, 948, 900, SafeViewportBounds.fit(948, 1048, full(948, 1048),
            Collections.singletonList(new SafeViewportBounds.Box(428, 900, 948, 1048)),
            "samsung", "SM-F776U1"));
    }

    @Test public void punchHoleAndBarsAreHandledOnce() {
        SafeViewportBounds.Box bars = new SafeViewportBounds.Box(0, 24, 1080, 2352);
        assertBox(0, 40, 1080, 2352, SafeViewportBounds.fit(1080, 2400, bars,
            Collections.singletonList(new SafeViewportBounds.Box(510, 0, 570, 40)),
            "Google", "Pixel"));
    }

    @Test public void clippedOffsetCutoutUsesOnlyIntersectionWithAppWindow() {
        assertBox(0, 0, 948, 800, SafeViewportBounds.fit(948, 1048, full(948, 1048),
            Collections.singletonList(new SafeViewportBounds.Box(428, 800, 1100, 1200)),
            "samsung", "SM-F776U1"));
    }

    @Test public void multipleCutoutsLeaveLargestUnobstructedRectangle() {
        SafeViewportBounds.Box upper = new SafeViewportBounds.Box(400, 0, 600, 60);
        SafeViewportBounds.Box lower = new SafeViewportBounds.Box(500, 800, 1000, 1000);
        SafeViewportBounds.Box safe = SafeViewportBounds.fit(1000, 1000, full(1000, 1000),
            Arrays.asList(upper, lower), "other", "other");
        assertBox(0, 60, 1000, 800, safe);
        assertFalse(safe.overlaps(upper));
        assertFalse(safe.overlaps(lower));
    }
}
