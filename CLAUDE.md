# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native SwiftUI strange-attractor visualizer for iOS. Renders the live,
animated trajectory of classic chaotic ODE systems edge-to-edge (2D canvas
trail or rotatable 3D SceneKit phase space), plus a Home Screen widget that
shows a static attractor. `attractive-web/` is a separate, gitignored local
sidecar (the original web build this app ports math from) — not part of the
iOS build.

## Build & test

```bash
# Regenerate the Xcode project from project.yml (ALWAYS after editing project.yml)
xcodegen generate

xcodebuild -project Attractive.xcodeproj -scheme Attractive \
  -sdk iphonesimulator -configuration Debug build

# AttractiveCore (AttractiveKit SwiftPM package) can be built/tested standalone:
cd AttractiveCore && swift build
cd AttractiveCore && swift test                       # all tests
cd AttractiveCore && swift test --filter RingBufferTests   # single test class
```

`Attractive.xcodeproj` is gitignored (generated artifact) — never hand-edit
`project.pbxproj`; change `project.yml` and run `xcodegen generate` instead.
`swift test` writes to `AttractiveCore/.build/` — that directory can grow
large and has previously broken `xcodegen generate` by getting swept into
the app target's sources; if `xcodegen generate` misbehaves, `rm -rf
AttractiveCore/.build` first. Simulator names are ambiguous across Xcode
versions — target simulators by UDID, not name.

Prefer the `XcodeBuildMCP` tools over raw `xcodebuild` shell calls when
available (build_run_sim, test_sim, etc.) — call `session_show_defaults`
first each session to confirm project/scheme/simulator.

## Apple versioning — single source of truth

`project.yml` (`settings.base.MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`)
is the *only* place app/build version should be set. Both the `Attractive`
app target and the `AttractiveWidgets` extension target read from these same
two variables. Apple's `ValidateEmbeddedBinary` check requires the
extension's `CFBundleShortVersionString` to match its containing app —
bumping the version in Xcode's target editor (or via `agvtool` on just one
target) desyncs the two and produces a build warning/failure. Always bump
the version in `project.yml`, then run `xcodegen generate`.

## Android shell and version ownership

Android uses the offline WebView shell described in [android/README.md](android/README.md).
Its version source is `android/version.properties`; `project.yml` above owns
Apple targets only. `scripts/prepare-android-web.sh` prepares the local web
sidecar into generated `android/web`, including the authored adapter
`android/accessibility.js`. Do not hand-edit generated web output.

The November 5 private Flip checkpoint is 1.0.5 (6), source `45e4b15`.
The [dated restoration and focus record](docs/flip-cover-accessibility-20261104.md#signed-candidate-and-native-keyboard-correction)
records saved-state restart and no-touch Escape evidence. The later
[quiet physical return](https://github.com/ambient-time/clocks-app/blob/codex/flip-apps-20261104/docs/reviews/flip-quiet-return-20261105.md) observes fresh inner Lessons retained on actual refold/cover resume and
native Escape before touch. This is bounded panel/focus evidence, not engine
serialization, uninterrupted foreground transfer, public release or TalkBack.

## Architecture

- **AttractiveCore** (`AttractiveKit` SwiftPM package, `AttractiveCore/`) —
  pure Swift, no UI, shared by both the app and the widget extension (they
  compile the same sources directly rather than linking a framework).
  - `AttractorConfig.swift` — value-type recipe (`Equatable, Codable,
    Hashable, Sendable`) plus an `AttractorID` enum (lorenz, rossler,
    aizawa, thomas, halvorsen, chen) carrying each system's Euler/RK4 ODE
    step, and a registry of starter attractors. Adding a new attractor is
    an enum case + a `step` branch + a registry entry — no other wiring.
  - `AttractiveEngine.swift` — integrates the selected attractor over `dt`,
    maintains a rolling trail of projected points (backed by
    `RingBuffer.swift`), exposes `regenerate(...)`, `advance(timeMs:)`,
    `points`, `trailPath()`.
  - `AttractiveSettings.swift` — `@MainActor @Observable` single source of
    UI/engine state with `UserDefaults` write-through.
  - `AttractorMetadata.swift` / `Lesson.swift` — descriptive/educational
    content (equations, lesson copy) shown in `EquationView`/`LessonsView`.
  - `LyapunovEstimator.swift` — chaos-sensitivity metric surfaced in the HUD.
  - `ViewMode.swift` — `canvas2D` vs `scene3D` display mode, pure value type.
- **Attractive** (app target, `Attractive/`) — `AttractiveApp` (`@main`,
  dark, status bar hidden). `ContentView` composes the canvas/scene, control
  bar, and picker sheet. `PhaseSpaceCoordinator` + `PhaseSpaceView` drive the
  SceneKit 3D mode; `AttractiveCanvas` + `TrailGeometry` drive the 2D
  `TimelineView(.animation)` + `Canvas` mode. `LaTeXLine`/`EquationView` use
  SwiftMath (the only third-party dependency) to render the attractor's ODE.
- **AttractiveWidgets** (app-extension target, `AttractiveWidgets/`) — a
  configurable Home Screen widget. `AttractorIntent` is the App Intent
  config (attractor chosen in the widget editor, no App Group needed since
  it's stateless). `AttractiveWidgets.swift` is the `WidgetBundle`/timeline
  provider (static entries refreshed once a day); `AttractorWidgetView`
  renders the still image using the same `AttractiveEngine` as the app.

## Release / App Store

`fastlane/Fastfile` drives App Store Connect interactions via the
`app_store_connect_api_key` action (reads
`APP_STORE_CONNECT_API_KEY_KEY_ID` / `_ISSUER_ID` / `_KEY` from the
environment — `source ~/.appstoreconnect/env.sh` first). Key lanes: `inspect`
(report versions/build states), `shots` (report screenshot/metadata
coverage), `upload_listing` (metadata only), `upload_screenshots` (stages
`screenshots-appstore/` into `build/screenshots/` and uploads). Screenshots
are pre-rendered attractor cards, not live simulator captures.

## Where things live

No secret is stored in this repository. Locations only:

| What | Where |
|------|-------|
| iOS build | `xcodegen generate`, then `xcodebuild` (see Build & test) |
| iOS release | Lanes in `fastlane/Fastfile`; App Store Connect API key under `~/.appstoreconnect/` on the release machine (`source ~/.appstoreconnect/env.sh` first) |
| Android build | `cd android && ./gradlew test assembleDebug` (JDK 21). Needs the gitignored `attractive-web/` sidecar next to `android/`: a checkout of `lukeslp/attractive-web` (branch `claude/play-fixes-20261112` until it is merged into `master`) with `vendor/` filled by `scripts/vendor-web-libs.sh`. It is not in this repository and a fresh clone cannot build Android without it; steps are in the README |
| Android release | `android/scripts/stage-release.sh`, run through `android-release-toolkit` with `scripts/android-release with-signing --profile attractive`; Play materials in `play/` |
| Android signing key | The `attractive` profile of `android-release-toolkit`: keystore under `~/Library/Application Support/AndroidReleaseToolkit/keystores/` on the release machine, password in the login Keychain |
| Store accounts | Apple Developer and App Store Connect; Google Play Console (closed-testing checklist in `play/`) |
