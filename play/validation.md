# Release validation

## 1.0.7 (8), November 12, 2026

Checked on Android 16 (API 36) emulators only. No signed build and no physical device yet.

### Binary

- Package: `attractive.lukesteuber.android`
- Version: 1.0.7 (8)
- Minimum SDK: 26
- Target SDK: 36
- Permissions: none
- Unsigned bundle SHA-256: `01fbf1955a9fd08c235441d4b5ca620b7eb5948c5adfef5cab4b34a5fdfc1bfc` (two builds of the
  same tree gave the same hash)
- Expected signing certificate SHA-256, as on every earlier release:
  `E1:1E:26:88:C8:F3:06:72:6D:3A:45:3B:D0:CE:D5:5D:A6:A0:5A:91:CC:B9:4B:98:B7:90:A9:34:20:DE:45:C1`

### Build and tests

```sh
cd android
./gradlew --no-daemon clean test lintRelease assembleRelease bundleRelease
```

- 19 unit tests in each variant, release lint: pass.
- `android/tests/accessibility.test.cjs` (Playwright, installed Chrome): pass.
- Instrumented restoration checks (`NativeUiRestorationChecks`) on an emulator at a compact window: pass.

### Installed-build checks

The APKs that `bundletool build-apks` cuts from the bundle were installed on a phone image (1080x2160, portrait
and landscape) and a tablet image (2560x1600 and 1200x1920) and driven by touch:

- 2D and 3D views, every drawing style, rotation
- every toolbar button reachable in both orientations
- controls menu, theme and style pickers, Advanced Controls
- guided lessons with the picture visible at every size
- equations panel, Lyapunov readout
- Export as PNG in 2D and 3D: the Save dialog, a valid PNG in Downloads
- About, the open-source notices page, Back from every panel
- start in airplane mode
- two-finger pinch and pan with real multi-touch events; one-finger drag; tap to inspect a point

Accessibility:

- TalkBack 16 on the phone image, stepped item by item through the main screen, the controls menu, the
  lessons list and a lesson step, About, the equations panel and the notices page. Every control has a name
  and a role; opening a panel moves focus into it; a lesson step is announced once.
- Font scale 1.3 and 2.0: nothing cut off; long text scrolls.
- Text contrast scan of every screen: no text under 4.5:1.
- Touch targets: none under 48 px tall.

Known limits:

- TalkBack reads each equation symbol by symbol. One spoken sentence per equation would need written-out
  wording for every formula.
- Not checked: physical devices, Android below 16, the signed build.

### Privacy and network posture

Unchanged: no permissions, WebView network loads blocked, bundled content only. Export as PNG writes one file
to the place the person chooses in the system Save dialog.

### Privacy URL

`https://dr.eamer.dev/attractive/privacy.html` serves the policy in `policy/privacy-policy.html` (effective
November 12, 2026).

## Record for 1.0.0 (1), July 20, 2026

Kept as written at the time. The faults listed in `README.md` were found later.

### Binary identity

- Package: `attractive.lukesteuber.android`
- Version: 1.0.0 (1)
- Minimum SDK: 26
- Target SDK: 36
- AAB SHA-256: `af475c4fd04e9d18d6cfb2058f45271bd75674924eb7c52393a322efebc96bb0`
- APK SHA-256: `278886b8f3c64b77b86bd49d0c7df4b502ded0b7e7c98c9182c40f67aa8c7a2f`
- Signing certificate SHA-256: `E1:1E:26:88:C8:F3:06:72:6D:3A:45:3B:D0:CE:D5:5D:A6:A0:5A:91:CC:B9:4B:98:B7:90:A9:34:20:DE:45:C1`

`jarsigner` verifies the AAB. `apksigner` verifies APK Signature Scheme v2 and v3 with one signer. The AAB was rebuilt from source with JDK 21 and the release profile; the rebuilt bundle was byte-for-byte identical to the staged bundle.

### Build and tests

Command:

```sh
env JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home \
  "$ANDROID_RELEASE_TOOLKIT"/scripts/android-release \
  with-signing --profile attractive -- \
  ./android/gradlew -p android clean test lintRelease assembleRelease bundleRelease
```

`ANDROID_RELEASE_TOOLKIT` is the checkout of the separate release-signing wrapper on the release machine; it supplies the `ATTRACTIVE_STORE_*` signing variables to the wrapped command.

Result: Gradle build successful, including unit tests and release lint.

### Installed-device checks

- Exact signed release APK installed and launched on a Pixel 10 phone.
- Exact signed release APK installed and launched on an Android 15 7-inch tablet profile at `sw617dp`.
- Main visualization, menu, style controls, content details, playback controls, and fullscreen behavior were manually exercised.
- Hardware-keyboard focus reached the skip link and displayed a high-contrast focus treatment.

### Assets

- App icon: opaque 512 x 512 PNG
- Feature graphic: opaque 1024 x 500 PNG
- Phone screenshots: four authentic 1080 x 2160 PNGs
- 7-inch tablet screenshots: four authentic 1080 x 1920 PNGs
- All screenshots were visually reviewed and contain no credentials, notifications, device frames, or fabricated interface content.

### Privacy and network posture

The Android manifest requests no permissions. The activity blocks WebView network loads and serves bundled content, so the release needs no account, network access, analytics, advertising, or tracking declarations.

### Privacy URL

`https://dr.eamer.dev/attractive/privacy.html` serves the dual-platform policy from `policy/privacy-policy.html` (effective July 21, 2026). The web app remains at `/attractive/`. Safe to submit Data safety against the privacy URL.
