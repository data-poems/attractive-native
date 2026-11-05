# Android cover keyboard and focus — November 4, 2026

Current workstream checkpoint, November 5: private signed **1.0.5 (6)** was
installed and passed native saved-state restoration and immediate no-touch
Escape. See [the latest artifact and focus correction](#signed-candidate-and-native-keyboard-correction).
Final physical unfold/refold is still pending; this is not a public release.

Historical November 4 status: source, quiet browser checks, signed release checks
and selected quiet keyboard journeys in the actual closed-cover Android WebView
passed. Version 1.0.3 (4) was installed at that checkpoint. Actual TalkBack acceptance was intentionally
skipped at Luke's request; it did not pass. Physical fold continuity for this
artifact remains pending. The earlier signed cover artifact's evidence remains
separate.

The existing offline web build reproduced two keyboard barriers at 598 × 530
CSS pixels: Space on the Lessons button paused animation without opening Lessons,
and Tab could enter the offscreen closed settings menu. The continuously updating
statistics group also requested polite live announcements (FPS updates each
second; enabled Lyapunov telemetry can update every 100 ms).

The tracked `android/accessibility.js` adapter keeps native button Space
activation and target key handlers, excludes hidden panes with `inert` and
`aria-hidden`, and leaves statistics as a labelled readable group with
`aria-live="off"`. Explicit user-action announcements remain enabled. At the
web app's existing compact breakpoint (768 CSS pixels), menu, Lessons and
Equations are modal dialogs: the background is inert, background shortcuts do
not run, Tab stays inside, and Escape uses the existing Close handler. Visibility
sync restores background state before moving focus once on open or close, so
lesson-step focus remains intact. Returning to a late toolbar action reveals it
inside the horizontal scrollport. Desktop sidebars and panels remain nonmodal;
About remains modal at either size. Resizing clears/restores isolation and moves
focus away from the desktop-hidden menu Close button.

`scripts/prepare-android-web.sh` copies and loads this adapter before `main.js`;
it fails if the expected main script is missing or duplicated. The separate,
ignored web checkout was not edited: its origin is
`https://github.com/lukeslp/attractive-web.git` and revision is
`1f1cb12509aaedefe1901b94dc4de8a8e9e52bf5`. Its existing untracked vendor tree is
unchanged. No generated `android/web` file was hand-edited. Native source baseline
was `1a57f1357b4e01871a9080a681f3bdb28e76fdec`.

Run the regression checks with an available Playwright module and installed
Google Chrome:

```sh
PLAYWRIGHT_MODULE=/path/to/playwright node android/tests/accessibility.test.cjs
```

The runner stages assets through the real preparation script in a temporary
tree, reproduces the baseline defects with only the adapter omitted, then tests
598 × 530, 372 × 662, 360 × 840 and desktop 1200 × 900. It checks native Space and
canvas shortcuts, hidden controls, modal semantics/isolation, Tab/Escape/focus
return, lesson focus, menu and panel resizing, visible toolbar focus, preserved
FPS DOM updates, and unchanged explicit live announcements. The compact pages
had no page errors or external requests. Results are in
`docs/reviews/flip-cover-accessibility-browser-20261104.json`. JavaScript syntax,
shell syntax and `git diff --check` also passed. These are browser-only results;
that JSON receipt is not Android device evidence.

## Signed build and quiet cover results

The coordinating session built and installed 1.0.3 (4) in place with the existing
release certificate. All 13 JVM tests, lint and the release build passed; local
output is `/tmp/attractive-quiet-accessibility-release-20261104.log`.

- APK SHA-256: `a5677bed321313a51273ce71845c3ccdfc0de0e0025dd5a66d39b196bb6181db`.
- Certificate SHA-256: `e11e2688c8f306726d3a453bd0ced55da6a05a91ccb94b98b790a93420de45c1`.

On the actual closed Flip cover, quiet keyboard input verified:

- Tab reached the skip link; the next Tab and Space opened the menu and focused
  its Close control. Escape dismissed it and restored hamburger focus.
- Eleven Tabs skipped the hidden menu controls and reached the final Lessons
  toolbar button, fully scrolled into view.
- Space opened Lessons with Close focused while the animation remained playing.

Temporary screenshots are `/tmp/attractive-quiet-keyboard-menu.png`,
`/tmp/attractive-quiet-late-keyboard-focus.png` and
`/tmp/attractive-quiet-lessons-before-fold.png`. These observations establish
the selected keyboard paths on this device and artifact, not every dialog or
physical fold transition. TalkBack remains off; the coordinating session verified
accessibility enabled state `0` and enabled service list `null` after Luke's
cancellation. No audible screen-reader checks were resumed.

The implementation uses native `inert`, which requires a current Android
WebView; the app's minimum Android version alone does not guarantee that runtime.
Other WebView versions and screen-reader acceptance remain unverified. No
permissions, network policy, math or saved-data schema changed. The coordinating
session owns final cross-repository receipts and remaining physical fold checks.

On November 5, the app resumed normally on the actual inner screen. Lessons was
closed after intervening phone use and could be opened normally. The fresh
panel is prepared for a controlled return-to-cover check, pending an actual
CLOSED posture. This is not evidence that folding itself lost the panel.
The [inner-screen follow-up](https://github.com/ambient-time/clocks-app/blob/b1038d7bbc162ada910fa5d61ba0f3ac13132970/docs/reviews/flip-quiet-checks-20261104.md)
retains the screenshot and exact boundaries. Astra noted that this manifest
does not handle density and that WebView saved history is not live DOM/panel
restoration. Establish a configuration/relaunch cause before changing either
the manifest or persistence. No new runtime build was made for this observation.

The behavior follows the W3C [modal dialog pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/)
and HTML's [inert subtree semantics](https://html.spec.whatwg.org/multipage/interaction.html#inert-subtrees).
Rollback removes the adapter and its preparation hook; no data migration or
uninstall is needed.

## November 5: transient panel recreation fix

The coordinating session observed the open Lessons browser disappear when the
cover host resumed the app. Samsung's scoped ActivityThread log explicitly
reported `relaunchActivityIfWebViewAttached` / `has WebView, Relaunching` at
01:39:38, in the same process and task. This was an observed native recreation,
not an established density-change cause.

Against source baseline `f70f7159876bff58fc122a1481a62af599827513`, the Android
adapter now exposes `window.__restoreNativeUiSession(boolean)` synchronously,
queuing early calls until feature setup finishes. The native client invokes it
only for the owned main asset, with saved-instance restoration true until the
first accepted current-document callback. Later documents bootstrap fresh;
duplicate calls are ignored per document, and a generation guard rejects stale
native callbacks. A saved instance is not necessarily a physical fold.
This single app-storage projection does not provide independent multiwindow
session restoration.

One versioned localStorage snapshot records open panel IDs/order, bounded scroll
positions and a stable focus ID. Writes start only after native bootstrap and
pause during replay. Fresh starts discard stale projections; recreation uses
the existing control handlers before restoring isolation and visible focus.
Closed state is saved too. Malformed, unavailable or full storage leaves the
live UI usable. No native JavaScript interface or permission was added.

This restores the menu, Equations, About/help and Lessons **panel/browser
projection**. It does not serialize engine state, settings, rendered DOM or an
in-progress lesson's selected step. Lesson-step handlers are not replayed, so
restoration does not apply their presets or duplicate their announcements.
Existing lesson interaction and explicit announcements remain unchanged.

The expanded real-preparation browser runner checks reload restoration, scroll
and safe focus, ordered overlays, closed-state persistence, one-shot/early
bootstrap, fresh-document writers, invalid focus, malformed/blocked/full
storage, and the earlier four-size keyboard regressions. Its local output is
`/tmp/attractive-ui-session-browser-20261105.log`. These are browser checks;
native build and actual recreation acceptance for this fix belong to the
coordinating session. Reverting this section's source
change removes the native bootstrap and adapter snapshot behavior; existing
lesson completion/settings storage keys are untouched.

### Signed candidate and native keyboard correction

The candidate installed and tested at this November 5 checkpoint is **1.0.5 (6)**. APK SHA-256:
`4863c0e25df5640b63f66bfef19a955388c788e21c6d699c563b6de2b04c72ad`;
existing certificate SHA-256 remains
`e11e2688c8f306726d3a453bd0ced55da6a05a91ccb94b98b790a93420de45c1`.
All 13 JVM tests, lint and signed release build passed. The
[expanded browser receipt](reviews/native-ui-session-browser-20261105.json)
is browser-only: restoration scenarios use 598×530 with desktop/compact overlay
coverage, alongside the earlier four-size keyboard checks.

Intermediate build 5 restored Lessons on a native saved-state restart, but Escape
was ignored until touching the content. DOM focus had not focused the new native
WebView. The owned-page callback now requests native view focus only when absent,
before replaying DOM focus. Astra found no blocker in that bounded correction.

On the actual CLOSED0 Flip, build 6 restored Lessons after background saved-state
process restart 26328 → 26805. Escape then dismissed it **without any touch first**,
and restart 26805 → 27110 kept it closed. Settings/playback remained unchanged; the
lesson browser was freshly reopened for the physical check. These tests kill
only the background test app after its state is saved, preserve app data and
do not establish a physical fold. New-build physical unfold/refold is pending.
No public APK or store release was made; TalkBack stayed off.
