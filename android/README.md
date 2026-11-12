# Attractive Android

Offline WebView shell for **Strangely Attractive**. The UI is the static
`attractive-web` app, prepared into `android/web` and loaded from
`file:///android_asset/` with network loads blocked.

This is the same pattern as Cube / Jankify, not Capacitor.

## Requirements

- JDK 21
- Android SDK Platform 36 + Build-Tools 36
- Local `../attractive-web` tree (ignored by Git) with vendored libraries under `attractive-web/vendor/`

## Prepare offline web assets

`attractive-web` is a checkout of the separate `lukeslp/attractive-web`
repository (branch `master`). The [root README](../README.md#build-the-android-app)
explains how to obtain it and why the public `data-poems/attractive` repository
is not a drop-in replacement.

```bash
# Once, from the repository root: get the web app and its libraries
git clone https://github.com/lukeslp/attractive-web.git attractive-web
# 1.0.6 needs five commits on top of master that are not on GitHub (the
# repository is archived). See "What attractive-web/ is" in the root README:
# git -C attractive-web am /path/to/sidecar-patches/*.patch
scripts/vendor-web-libs.sh   # three / rough / katex into attractive-web/vendor/

# Each build: rewrite CDN tags into android/web
../scripts/prepare-android-web.sh
```

`preBuild` runs the prepare script automatically.

## Current Flip checkpoint, November 5, 2026

Private signed **1.0.5 (6)** is the latest artifact tested by this workstream.
Its [restoration/focus receipt](../docs/flip-cover-accessibility-20261104.md#signed-candidate-and-native-keyboard-correction)
records the exact APK, native saved-state restart, restored Lessons browser and
Escape without a prior touch. Final physical unfold/refold remains pending;
TalkBack was skipped. Versioning comes from `version.properties`. This checkpoint
is not a public Android release. Recheck installed identity before further tests.

## Historical cover geometry checkpoint, November 4, 2026

The local 1.0.2 (3) candidate adds a native safe viewport, a scrolling toolbar
and reachable panel controls. The signed final build passed actual closed-cover
launch and wide/tall/full resizing. Physical fold continuity and TalkBack remain
unverified. See the [dated build and device evidence](../docs/flip-cover-20261104.md);
this candidate has not been publicly released.

## Build

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
./gradlew test assembleDebug
# APK: app/build/outputs/apk/debug/app-debug.apk
```

## Signed release staging

Optional environment variables (never commit these):

- `ATTRACTIVE_STORE_FILE`
- `ATTRACTIVE_STORE_PASSWORD`
- `ATTRACTIVE_KEY_ALIAS`
- `ATTRACTIVE_KEY_PASSWORD`

```bash
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
./scripts/stage-release.sh
```

Writes the same bundle to both:

- `../release/android/<version>+<code>/` (local convenience)
- `../dist/platforms/android/<version>+<code>/` (**platforms** suite convention)

Each stage dir includes APK, AAB, `SHA256SUMS`, `PROVENANCE.md`, and
`UPLOAD_CHECKLIST.md`. Without release signing env vars you get **unsigned**
release artifacts plus a debug-keystore **testing** APK for sideload.

## Security posture

- No Android permissions
- `blockNetworkLoads = true`
- External http(s) links open in the system browser only on user gesture
- Export as PNG saves through the system file picker; no storage permission
- License texts for the bundled libraries are in `notices/` and shown in the app
  (About, Open-Source Notices)
- No cleartext traffic; no backup of private files

## Automated emulator follow-up

The [guarded native restoration suite](../docs/native-restoration-emulator-20261105.md)
now exercises real Activity recreation, native Escape without a prior touch,
closed-state persistence and later-document writers using only synthetic emulator
data. It does not close the physical fold or signed-release acceptance gates.
