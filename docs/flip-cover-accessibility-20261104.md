# Android cover keyboard and focus — November 4, 2026

Status: source, quiet browser checks, signed release checks and selected quiet
keyboard journeys in the actual closed-cover Android WebView passed. Version
1.0.3 (4) is installed in place. Actual TalkBack acceptance was intentionally
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

The behavior follows the W3C [modal dialog pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/)
and HTML's [inert subtree semantics](https://html.spec.whatwg.org/multipage/interaction.html#inert-subtrees).
Rollback removes the adapter and its preparation hook; no data migration or
uninstall is needed.
