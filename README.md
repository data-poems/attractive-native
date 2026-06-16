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
