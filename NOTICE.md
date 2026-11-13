# Third-party notices

The source in this repository is copyright (c) 2026 Luke Steuber and released
under the MIT License in [LICENSE](LICENSE), except for the third-party files
listed under "In this repository". The other sections list software that is
not stored here but is fetched at build time and ends up in a built app.

## In this repository

| Files | Project | License |
|-------|---------|---------|
| `android/notices/*.txt` | License texts of three.js, Rough.js, KaTeX and the KaTeX fonts | Each file is the license it reproduces |
| `android/gradlew`, `android/gradlew.bat`, `android/gradle/wrapper/gradle-wrapper.jar` | Gradle Wrapper (Gradle 8.14.5 distribution pinned in `gradle-wrapper.properties`) | Apache License 2.0 |

## Fetched at build time and included in the iOS app

| Project | Version | License |
|---------|---------|---------|
| [SwiftMath](https://github.com/mgriebling/SwiftMath) | 1.7.0 or later (Swift Package Manager; 1.7.3 at the last check) | MIT, copyright Computer Inspirations |
| Math fonts inside SwiftMath's `mathFonts.bundle` | as shipped by SwiftMath | Each font keeps its own license (for example the GUST Font License for Latin Modern Math); see the `LICENSE` and `GUST-FONT-LICENSE.txt` files in that bundle |

## Fetched at build time and included in the Android app

`scripts/vendor-web-libs.sh` downloads these into `attractive-web/vendor/`, and
`scripts/prepare-android-web.sh` copies them into the app's assets. Their
license texts are stored in `android/notices/` and the same script builds them
into the page the app shows under About, Open-Source Notices.

| Project | Version | License |
|---------|---------|---------|
| [three.js](https://github.com/mrdoob/three.js) | 0.149.0 | MIT, copyright the three.js authors |
| [Rough.js](https://github.com/rough-stuff/rough) | 4.6.6 | MIT, copyright Preet Shihn |
| [KaTeX](https://github.com/KaTeX/KaTeX) JavaScript and CSS | 0.16.11 | MIT, copyright Khan Academy and other contributors |
| KaTeX fonts (WOFF2) | 0.16.11 | SIL Open Font License 1.1, copyright Design Science, Inc. and Khan Academy |

The Android app's interface is the separate `attractive-web` web app (see the
README). It is not part of this repository and is not covered by this
repository's license.

## Build and test tooling (not distributed with the apps)

| Project | Use | License |
|---------|-----|---------|
| Android Gradle Plugin 8.13.0, Kotlin Gradle plugin 2.2.21 | Android build | Apache License 2.0 |
| JUnit 4.13.2 | Android unit tests | Eclipse Public License 1.0 |
| [fastlane](https://github.com/fastlane/fastlane) 2.236.0 | App Store Connect lanes | MIT |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | generates the Xcode project | MIT |
