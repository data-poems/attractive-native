# Flip cover adaptation, November 4, 2026

Status: signed local candidate installed; browser, JVM and selected physical
cover checks passed. The final artifact cold-launched from the real SystemUI
cover App Tray and passed wide/tall/full resizing and Lessons open/dismiss checks.
Physical unfold/refold continuity and TalkBack remain pending.
Android 1.0.2 (3) updates the existing package and release
certificate. It has not been published to a download catalog or store.

## Change and reuse

At 379 × 336 CSS pixels the existing floating toolbar extended past x499, hiding
Equations, 3D, Lyapunov and Lessons. Its smallest buttons were 36 pixels. The
Android asset preparation now includes the tracked `android/compact-window.css`
at widths up to 640 CSS pixels. The toolbar scrolls horizontally
and has 48-CSS-pixel controls; the status panel sits above it with a bottom offset
of 88 CSS pixels. Menu/panel close
controls are 48 CSS pixels, and panel bodies remain scrollable. These dimensions
are web targets, not a claim of 48 physical Android dp under Samsung scaling.
Short windows up to 600 CSS pixels high additionally put stats at the top right
and adapt the panel bodies and onboarding tooltip. Tall windows and narrow inner
phones keep the scrolling toolbar and reachable close controls. The independent web sidecar and generated `android/web`
are not edited by hand.

The native shell retains its WebView and uses a `SafeViewport` parent instead of
unbounded window layout. It fits a clear rectangle around visible system bars
and actual cutout bounds, consuming those insets once. It observes inset, size
and layout changes. Bounds are calculated from the incoming window measure specs
before `FrameLayout` measures the WebView; inset changes request measurement and
origin changes queue a fresh pass outside layout. Samsung's compatibility-frame cutout outside the app window
does not remove usable space again. Only Samsung SM-F766/SM-F776 windows within
3% of the portrait 948:1048 shape use a no-cutout fallback, reserving the strip
below y839/1048. The fallback comes from the physical Flip8 measurements in
Ambient Time's `docs/reviews/flip-cover-launch-20261104.md`; it is an estimate
for Samsung's full-panel mode, not a platform guarantee.

The Java rectangle policy, wrapper and eight geometry tests were adapted from
the concurrent Hexsweeper native shell change (`lukeslp/hexsweeper-app`, commit
`def4ab3`). Each app retains its thin shell and independent build. No permission,
network policy, attractor equation, integration or saved setting was changed.

## Evidence

JDK 21 and SDK 36, offline:

```sh
./android/gradlew -p android --offline testDebugUnitTest assembleRelease lintDebug
```

The release build used the existing `attractive` signing profile through Android
Release Toolkit. Its certificate matches the installed public 1.0.1 (2), so an
in-place update can preserve data. The current artifact checksum, test count and
the original sidecar input hashes are in
`docs/reviews/flip-cover-build-20261104.json`. The existing API 36 target remains;
the newly raised `OldTargetApi` lint notice is explicitly suppressed rather than
silently migrating SDK behavior in this viewport change. The installed Gradle
wrapper is also retained, with the `AndroidGradlePluginVersion` update-availability
notice suppressed separately from source correctness checks. Other lint checks pass.

Touch-enabled Chromium exercised the actual prepared offline assets at
379 × 336, 399 × 353 and 550 × 400. It checked toolbar bounds and target sizes,
scrolled to the final action, opened/dismissed Lessons and Equations, scrolled
settings, and resized through an inner-phone window. No page errors or external
requests occurred. Details are in `docs/reviews/flip-cover-browser-20261104.json`.
These are browser checks, not Android touch, GPU, fold or TalkBack evidence.

Physical Samsung SM-F776U1 cover evidence then exposed two gaps that the browser
checks could not detect. Its wide app window measured 1422×1259 native pixels,
but WebView exposed approximately 598×530 CSS pixels at DPR 2.375 rather than the
Activity's compatibility density of 3.0. All stylesheets loaded; the former
600×480 media query simply did not match. Enabling `useWideViewPort` had no
observed effect and was removed. The compact rule now includes this actual
short-window size without changing display density or page zoom. Browser checks
at 598×530 and 598×600 confirm 48×48 CSS buttons, a horizontally scrollable toolbar,
and stats at top 12 pixels. Additional touch-enabled browser checks at 372×662,
360×840 and 598×530 confirm that the toolbar stays inside the viewport, every
visible toolbar action has a 48×48 CSS target, stats do not overlap the toolbar,
the final Lessons action can be scrolled fully into view, and Lessons opens and
closes with an in-bounds 48×48 CSS close target. No page errors or external
requests occurred. Tall windows remain outside the short-window HUD rule while
keeping the width-based toolbar adaptations.

Warm resizing through Samsung's wide → tall → full-panel modes also showed that
changing padding during layout could clip an already measured full-height
WebView. Before correction, full mode had root 1422×1572 with bottom padding 314,
but child measured/actual size stayed 1422×1572 and DOM height 662. Computing the
padding before child measurement corrected the same repeated resize on hardware:

| Mode | Native root | Bottom padding | WebView measured and actual | DOM inner size | Short-window HUD |
|---|---|---|---|---|---|
| Wide | 1422×1259 | 0 | 1422×1259 | 598×530 | Yes |
| Tall | 885×1572 | 0 | 885×1572 | 372×662 | No |
| Full panel | 1422×1572 | 314 | 1422×1258 | 598×529 | Yes |

The settled full-panel visual viewport was approximately 598.74×529.68 at scale
1. A physical horizontal toolbar swipe revealed the last Lessons button fully
above the camera strip beginning at physical y839. Local evidence is in
`/tmp/attractive-fixed-resize-metrics.log` and
`/tmp/attractive-fixed-full-toolbar.png`. The probe collected geometry only; all
temporary logging and listeners were removed from production source, and release
WebView debugging/security settings remain unchanged.

The coordinating session then installed the final production artifact with
SHA-256 `f2924f069d7b185df5948a6e6da5a8934cf66ef50ac371d71469a51c330ca050`.
After force-stopping the old probe process, it cold-launched the app by tapping
its real SystemUI App Tray icon on the closed Flip's display 1. The final
wide → tall → full → wide sequence passed. In the full frame, the recorded
toolbar swipe `(850,765) → (250,765)` exposed the final Lessons action at
`(885,765)`; it opened Guided Lessons, and the close control at `(890,50)`
dismissed the panel on the physical cover. Camera clearance was correct, and
the tall-frame bottom statistics did not overlap the toolbar. These are recorded
cover input coordinates, not CSS-pixel or Android-dp measurements.

Final screenshots are temporarily stored on the build machine at
`/tmp/attractive-cover-final-wide.png`, `/tmp/attractive-cover-final-tall.png`,
`/tmp/attractive-cover-final-full.png` and
`/tmp/attractive-cover-final-lessons.png`. The build receipt records this final
artifact evidence separately from the earlier probe. It does not establish
physical unfold/refold continuity or TalkBack behavior.

The local sidecar is the same ignored snapshot used by the existing Android
build checkout. This change preserves those inputs; it does not establish a new
canonical web-source revision. A fresh build still needs that separately
provisioned sidecar and vendored dependencies as documented in `android/README.md`.

Durable evidence is retained in the [coordinating handoff](https://github.com/ambient-time/clocks-app/blob/7466a6dd8fbb0cdaef20292289b22f82bf8f655f/docs/reviews/flip-apps-20261104.md)
and [final full-frame Lessons screenshot](https://github.com/ambient-time/clocks-app/blob/7466a6dd8fbb0cdaef20292289b22f82bf8f655f/docs/reviews/assets/flip-apps-20261104/attractive-full-lessons.png).
The `/tmp` paths above are transient local captures. The equivalent viewport in
`lukeslp/hexsweeper-app` is maintained separately; review changes to measurement
order, inset clearing and origin updates in both shells.

## Remaining physical check and rollback

Physical unfold/refold continuity and TalkBack remain to check with the installed
final artifact. The verified cold tray launch, frame resizing, toolbar swipe and
Lessons dismissal do not establish every interaction or accessibility behavior.

Rollback reverses the native wrapper, compact stylesheet and preparation hook;
it does not change the saved-data schema. Do not uninstall the production app to
resolve a signing mismatch. Public distribution remains a separate operation.
