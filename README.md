# Attractive

A native SwiftUI strange-attractor visualizer for iOS. Renders the live,
animated trajectory of classic chaotic ODE systems edge-to-edge, with a
minimal control bar and an attractor picker.

## Architecture

- **AttractiveCore** (`AttractiveKit` SwiftPM package) — pure Swift, no UI.
  - `AttractorConfig.swift` — value-type recipe (`Equatable, Codable,
    Hashable, Sendable`) plus an `AttractorID` enum carrying each system's
    Euler ODE step, and a registry of starter attractors.
  - `AttractiveEngine.swift` — integrates the selected attractor over `dt`,
    maintains a rolling trail of projected points, exposes `regenerate(...)`,
    `advance(timeMs:)`, `points`, and `trailPath()`.
  - `AttractiveSettings.swift` — `@MainActor @Observable` single source of
    truth with `UserDefaults` write-through.
  - `ReviewPromptPolicy.swift` — persistent session history and the tested
    eligibility rules for the lesson-completion review request.
- **Attractive** (app) — `AttractiveApp` (`@main`, dark, status bar hidden),
  `AttractiveCanvas` (`TimelineView(.animation)` + `Canvas`), `ContentView`
  (canvas + control bar + picker sheet).

The six starter attractors (Lorenz, Rössler, Aizawa, Thomas, Halvorsen,
Chen) port their ODE math faithfully from the web `datavis/attractive`
build. The `step` switch and registry are shaped so more systems drop in by
adding an enum case and a registry entry.

## Build

```bash
xcodegen generate
xcodebuild -project Attractive.xcodeproj -scheme Attractive \
  -sdk iphonesimulator -configuration Debug build

# Validate the package alone:
cd AttractiveCore && swift build
```

In a Debug build, pass `-ForceReviewPromptEligible` as a launch argument or
set `ATTRACTIVE_FORCE_REVIEW_PROMPT=1` to exercise the review-request path
without waiting for the normal lesson, session, and time thresholds.

## Android

Offline WebView shell (same pattern as Cube / Jankify, not Capacitor). The
shell loads a prepared copy of `attractive-web` with vendored three.js,
Rough.js, and KaTeX; network loads are blocked.

```bash
# Requires attractive-web/ (local sidecar) with vendor/ libs present.
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
cd android
./gradlew test assembleDebug
# Stage APK/AAB + checksums (release/android and dist/platforms/android):
./scripts/stage-release.sh
```

Optional release signing env: `ATTRACTIVE_STORE_FILE`, `ATTRACTIVE_STORE_PASSWORD`,
`ATTRACTIVE_KEY_ALIAS`, `ATTRACTIVE_KEY_PASSWORD`. Without them, staging still
produces unsigned release artifacts plus a debug-keystore **testing** APK.

See [android/README.md](android/README.md).

The local Flip candidate is 1.0.5 (6), with safe-window layout, compact keyboard
controls and bounded panel restoration after native WebView recreation. Build,
browser and native saved-state results, plus remaining physical checks, are in
the [dated cover receipt](docs/flip-cover-accessibility-20261104.md). It has not
been publicly released; iOS behavior is separate.

### Platforms suite

Root [`platforms.yml`](platforms.yml) lists the Android track for the
[`platforms`](https://github.com/actually-useful-ai/platforms) CLI (detect /
doctor / plan). Ambient Time multi-platform ports are out of scope here.

```bash
# from the platforms repo
PYTHONPATH=src:tools:. python3 -m platforms detect --project /path/to/attractive-ios --json
PYTHONPATH=src:tools:. python3 -m platforms doctor --project /path/to/attractive-ios --platform android --json
PYTHONPATH=src:tools:. python3 -m platforms plan --project /path/to/attractive-ios --platform android --json
```

Staged Android evidence: `dist/platforms/android/<version>+<code>/`.
