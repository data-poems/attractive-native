# Strangely Attractive

[![App Store](https://img.shields.io/badge/App_Store-iPhone_and_iPad-blue?style=flat-square)](https://apps.apple.com/us/app/strangely-attractive/id6780700164)
[![Android download](https://img.shields.io/badge/Android-direct_download-34A853?style=flat-square)](https://dr.eamer.dev/downloads/apps/strangely-attractive/)
[![F-Droid repository](https://img.shields.io/badge/F--Droid-LocalType_releases_repo-1976D2?style=flat-square)](https://dr.eamer.dev/downloads/fdroid/)
[![Web](https://img.shields.io/badge/web-dr.eamer.dev-4ad7d1?style=flat-square)](https://dr.eamer.dev/datavis/attractive/)
[![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

A strange-attractor visualizer. It draws the live trajectory of classic chaotic
systems (Lorenz, Rössler, Aizawa, Thomas, Halvorsen and Chen on iOS) in a 2D
canvas or a rotatable 3D phase space, shows the equations behind each one, and
walks through short lessons on sensitive dependence and the Lyapunov exponent.

This repository holds the native iOS app and the Android shell. In code and
project files the app is named "Attractive".

## At a glance

| | |
|---|---|
| What it is | Native SwiftUI app for iPhone and iPad with a Home Screen widget, plus an offline Android WebView shell around the separate `attractive-web` web app |
| Platforms | iOS and iPadOS 17.0 or later; Android 8.0 (API 26) or later, phone and tablet |
| Versions in this tree | iOS 1.0.2 (15) in `project.yml`; Android 1.0.6 (7) in `android/version.properties` |
| Release status | iPhone and iPad: [App Store](https://apps.apple.com/us/app/strangely-attractive/id6780700164). Android: signed APK at [dr.eamer.dev/downloads/apps/strangely-attractive](https://dr.eamer.dev/downloads/apps/strangely-attractive/) and in the hosted F-Droid repository. Google Play is in closed testing only (`play/`) |
| Web app | <https://dr.eamer.dev/attractive/> |
| Privacy policy | <https://dr.eamer.dev/attractive/privacy.html> (source in `play/policy/`) |
| iOS build | `xcodegen generate`, then `xcodebuild -project Attractive.xcodeproj -scheme Attractive -sdk iphonesimulator build` |
| Core tests | `cd AttractiveCore && swift test` |
| Android build | `cd android && ./gradlew test assembleDebug` (JDK 21, needs `attractive-web/`, see below) |
| License | MIT ([LICENSE](LICENSE)); third-party pieces in [NOTICE.md](NOTICE.md) |

## Layout

- `AttractiveCore/` is the `AttractiveKit` Swift package: pure Swift, no UI.
  - `AttractorConfig.swift` holds the value-type recipe for each system, the
    `AttractorID` enum with each system's Euler and RK4 step, and the registry
    of starter attractors. Adding a system is an enum case, a `step` branch and
    a registry entry.
  - `AttractiveEngine.swift` integrates the selected attractor and keeps a
    rolling trail of projected points (`RingBuffer.swift`).
  - `AttractiveSettings.swift` is the observable app state, written through to
    `UserDefaults`.
  - `AttractorMetadata.swift` and `Lesson.swift` hold the equations and lesson
    text. `LyapunovEstimator.swift` computes the sensitivity readout.
  - `ReviewPromptPolicy.swift` holds the rules for when the app may ask for a
    review.
- `Attractive/` is the app target: the 2D `Canvas` view, the SceneKit 3D view,
  equations, lessons and settings.
- `AttractiveWidgets/` is the widget extension. It draws a still attractor
  chosen in the widget editor, using the same engine.
- `android/` is the Android shell (see [android/README.md](android/README.md)).
- `fastlane/` holds App Store Connect lanes and the App Store listing text.
  `screenshots-appstore/` holds the listing images, which are rendered by
  `AttractiveCore/Tests/StoreCardGenerator.swift` rather than captured from a
  simulator.
- `play/` holds the Google Play listing, policy and checklist material.
- `docs/` holds dated test records for the Android shell.

The app and the widget compile the `AttractiveCore` sources directly; they do
not link the package as a framework.

## Build the iOS app

Requirements: macOS with Xcode (iOS 17 SDK or later) and
[XcodeGen](https://github.com/yonaskolb/XcodeGen). The Xcode project is
generated from `project.yml` and is not checked in.

```bash
xcodegen generate
xcodebuild -project Attractive.xcodeproj -scheme Attractive \
  -sdk iphonesimulator -configuration Debug build
```

Xcode fetches the one package dependency,
[SwiftMath](https://github.com/mgriebling/SwiftMath), which renders the
equations.

`project.yml` sets `DEVELOPMENT_TEAM` and the `com.lukesteuber` bundle
identifiers. To run on a device or archive under your own account, change
those values and run `xcodegen generate` again. The app version and build
number are also set only in `project.yml`, so the app and its widget stay in
step.

If `xcodegen generate` picks up stray sources, delete `AttractiveCore/.build`
and run it again.

### Core package tests

```bash
cd AttractiveCore
swift build
swift test
```

`swift test` also runs the listing-image generator, which writes PNG files to
a temporary folder.

In a Debug build, pass `-ForceReviewPromptEligible` as a launch argument or
set `ATTRACTIVE_FORCE_REVIEW_PROMPT=1` to exercise the review-request path
without waiting for the normal lesson, session and time thresholds.

### App Store Connect lanes

`fastlane/Fastfile` reads an App Store Connect API key from
`APP_STORE_CONNECT_API_KEY_KEY_ID`, `APP_STORE_CONNECT_API_KEY_ISSUER_ID` and
`APP_STORE_CONNECT_API_KEY_KEY`. No key is stored in this repository. The
account values in `fastlane/Appfile` can be overridden with `FASTLANE_USER`,
`FASTLANE_TEAM_ID` and `FASTLANE_ITC_TEAM_ID`.

```bash
bundle install
bundle exec fastlane ios inspect
ruby fastlane/release_helpers_test.rb   # helper unit tests, no network
```

## Build the Android app

The Android app is an offline WebView shell. Its interface is not in this
repository: the build copies a web app from a folder named `attractive-web/`
at the repository root, which Git ignores. A fresh clone cannot build Android
until that folder exists.

### What `attractive-web/` is

It is a checkout of the `lukeslp/attractive-web` repository on GitHub, branch
`master`, plus a `vendor/` folder of three.js, Rough.js and KaTeX that
`scripts/vendor-web-libs.sh` downloads. `master` at `1f1cb12` is what Android
1.0.1 to 1.0.5 were built from.

Android 1.0.6 (7) needs five more commits on top of `1f1cb12` (3D view size,
lesson layout and content, export of the visible view, corrected data
wording, 2D fit on narrow screens). `CanonicalWebAssetsTest` fails the build
on a web copy without them. Those commits are not on GitHub: the
`lukeslp/attractive-web` repository is archived, which makes it read-only, so
a branch cannot be pushed to it. They exist as a patch series
(`git format-patch`) and a Git bundle kept with the 1.0.6 release materials,
ending at commit `7cf8246`. Apply them with `git am` after cloning, or
un-archive the repository and push the branch.

That repository is private at the time of writing. The public repository
[data-poems/attractive](https://github.com/data-poems/attractive) is a later
version of the same web app. It is not a drop-in replacement: it loads KaTeX
and three.js from a different `vendor/` layout and adds files, so
`scripts/prepare-android-web.sh`, which expects the older CDN script tags,
stops with an error on it.

### Steps

Requirements: JDK 21, Android SDK Platform 36 and Build-Tools 36, `python3`,
`curl` and `bash`.

```bash
# From the repository root. Needs read access to the repository.
git clone https://github.com/lukeslp/attractive-web.git attractive-web

# Once: download three.js 0.149.0, Rough.js 4.6.6 and KaTeX 0.16.11
# (with its WOFF2 fonts) into attractive-web/vendor/.
scripts/vendor-web-libs.sh

export JAVA_HOME="$(/usr/libexec/java_home -v 21)"   # macOS; any JDK 21 works
export ANDROID_HOME="$HOME/Library/Android/sdk"       # or set sdk.dir in android/local.properties
cd android
./gradlew test assembleDebug
# APK: android/app/build/outputs/apk/debug/app-debug.apk
```

Each Gradle build runs `scripts/prepare-android-web.sh` first. It copies the
web app into the generated `android/web/` folder, points the script and style
tags at the vendored libraries, removes remote fonts and analytics, and adds
`android/compact-window.css` and `android/accessibility.js`. It also builds
`third-party-notices.html` from the license texts in `android/notices/` and
links it from the About dialog. Do not edit `android/web/` by hand.

The shell requests no Android permissions and blocks network loads in the
WebView. External links open in the system browser. Export as PNG hands the
image to the shell, which saves it through the system file picker
(`ACTION_CREATE_DOCUMENT`), so no storage permission is needed.

### Other Android checks

```bash
# Browser check of the accessibility adapter. Needs a Playwright module and
# an installed Chrome; neither is declared by this repository.
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright \
  node --test android/tests/accessibility.test.cjs
```

`scripts/check-native-restoration.py` runs the instrumented restoration checks
on a dedicated emulator only; see
[docs/native-restoration-emulator-20261105.md](docs/native-restoration-emulator-20261105.md).

### Release staging

```bash
cd android
./scripts/stage-release.sh
```

This runs `clean test lintRelease assembleRelease bundleRelease` and copies
the APK, AAB, checksums and a provenance note to
`release/android/<version>+<code>/` and `dist/platforms/android/<version>+<code>/`.
Signing is optional and read from the environment or Gradle properties:
`ATTRACTIVE_STORE_FILE`, `ATTRACTIVE_STORE_PASSWORD`, `ATTRACTIVE_KEY_ALIAS`
and `ATTRACTIVE_KEY_PASSWORD`. Without them the script produces unsigned
release files, plus a testing APK signed with the local Android debug keystore
when one is present. No keystore or password is stored in this repository.

Root [`platforms.yml`](platforms.yml) describes the Android track for the
[platforms](https://github.com/actually-useful-ai/platforms) command-line tool.

## License

The source in this repository is released under the MIT License; see
[LICENSE](LICENSE). The Gradle wrapper files under `android/` are Apache 2.0.
Built apps also include SwiftMath and its math fonts (iOS) and three.js,
Rough.js and KaTeX with its fonts (Android). [NOTICE.md](NOTICE.md) lists each
piece and its license. The `attractive-web` web app is a separate work and is
not covered by this repository's license.
