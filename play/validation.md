# Release validation

Validated on July 20, 2026.

## Binary identity

- Package: `attractive.lukesteuber.android`
- Version: 1.0.0 (1)
- Minimum SDK: 26
- Target SDK: 36
- AAB SHA-256: `af475c4fd04e9d18d6cfb2058f45271bd75674924eb7c52393a322efebc96bb0`
- APK SHA-256: `278886b8f3c64b77b86bd49d0c7df4b502ded0b7e7c98c9182c40f67aa8c7a2f`
- Signing certificate SHA-256: `E1:1E:26:88:C8:F3:06:72:6D:3A:45:3B:D0:CE:D5:5D:A6:A0:5A:91:CC:B9:4B:98:B7:90:A9:34:20:DE:45:C1`

`jarsigner` verifies the AAB. `apksigner` verifies APK Signature Scheme v2 and v3 with one signer. The AAB was rebuilt from source with JDK 21 and the release profile; the rebuilt bundle was byte-for-byte identical to the staged bundle.

## Build and tests

Command:

```sh
env JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home \
  /Users/luke/workspace/android-release-toolkit/scripts/android-release \
  with-signing --profile attractive -- \
  ./android/gradlew -p android clean test lintRelease assembleRelease bundleRelease
```

Result: Gradle build successful, including unit tests and release lint.

## Installed-device checks

- Exact signed release APK installed and launched on a Pixel 10 phone.
- Exact signed release APK installed and launched on an Android 15 7-inch tablet profile at `sw617dp`.
- Main visualization, menu, style controls, content details, playback controls, and fullscreen behavior were manually exercised.
- Hardware-keyboard focus reached the skip link and displayed a high-contrast focus treatment.

## Assets

- App icon: opaque 512 x 512 PNG
- Feature graphic: opaque 1024 x 500 PNG
- Phone screenshots: four authentic 1080 x 2160 PNGs
- 7-inch tablet screenshots: four authentic 1080 x 1920 PNGs
- All screenshots were visually reviewed and contain no credentials, notifications, device frames, or fabricated interface content.

## Privacy and network posture

The Android manifest requests no permissions. The activity blocks WebView network loads and serves bundled content, so the release needs no account, network access, analytics, advertising, or tracking declarations.

## Privacy URL

`https://dr.eamer.dev/attractive/privacy.html` serves the dual-platform policy from `policy/privacy-policy.html` (effective July 21, 2026). The web app remains at `/attractive/`. Safe to submit Data safety against the privacy URL.
