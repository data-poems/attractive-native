# Flip cover adaptation — November 4, 2026

Status: signed local candidate, browser and JVM checks passed; physical cover
validation is pending. Android 1.0.2 (3) updates the existing package and release
certificate. It has not been published to a download catalog or store.

## Change and reuse

At 379 × 336 CSS pixels the existing floating toolbar extended past x499, hiding
Equations, 3D, Lyapunov and Lessons. Its smallest buttons were 36 pixels. The
Android asset preparation now includes the tracked `android/compact-window.css`
at widths up to 600 and heights up to 480 pixels. The toolbar scrolls horizontally
and has 48-pixel controls; the status panel moves above it. Menu/panel close
controls are 48 pixels, and panel bodies remain scrollable. Taller windows retain
their existing layout. The independent web sidecar and generated `android/web`
are not edited by hand.

The native shell retains its WebView and uses a `SafeViewport` parent instead of
unbounded window layout. It fits a clear rectangle around visible system bars
and actual cutout bounds, consuming those insets once. It observes inset, size
and layout changes. Samsung's compatibility-frame cutout outside the app window
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
silently migrating SDK behavior in this viewport change. Other lint checks pass.

Touch-enabled Chromium exercised the actual prepared offline assets at
379 × 336, 399 × 353 and 550 × 400. It checked toolbar bounds and target sizes,
scrolled to the final action, opened/dismissed Lessons and Equations, scrolled
settings, and resized through an inner-phone window. No page errors or external
requests occurred. Details are in `docs/reviews/flip-cover-browser-20261104.json`.
These are browser checks, not Android touch, GPU, fold or TalkBack evidence.

The local sidecar is the same ignored snapshot used by the existing Android
build checkout. This change preserves those inputs; it does not establish a new
canonical web-source revision. A fresh build still needs that separately
provisioned sidecar and vendored dependencies as documented in `android/README.md`.

## Remaining physical check and rollback

Update the existing app without uninstalling it, select Strangely Attractive in
MultiStar's cover App Tray, close/unlock the Flip, and launch by tapping its icon.
Check the wide and full-panel frames, toolbar swiping, panel dismissal and
unfold/refold continuity. Do not call the adaptation device-tested before this.

Rollback reverses the native wrapper, compact stylesheet and preparation hook;
it does not change the saved-data schema. Do not uninstall the production app to
resolve a signing mismatch. Public distribution remains a separate operation.
