# Native restoration instrumentation, November 5, 2026

The current native runtime passes an automated saved-Activity-state and keyboard
sequence on a dedicated emulator. This adds repeatable evidence to the earlier
physical saved-process-restart receipt; it does not replace the still-pending
physical fold check.

Canonical HTTPS default main was verified at `80ac3275aa0d4349f7a0c9fe695a4b253db0b810` before
creating this isolated test worktree. Tests use a locally built **1.0.5-debug (6)**,
package `attractive.lukesteuber.android.debug`. It is not the signed APK installed on Luke’s phone.
No production runtime or generated web payload changed. Exact APK, test-source,
runtime-source and payload hashes are in the
[machine-readable receipt](reviews/native-restoration-emulator-20261105.json).
A test-APK-only `Instrumentation` runner uses platform APIs. The only Gradle change selects that runner; no runtime dependency or JavaScript bridge was added.

## What passed

The sequence uses the real MainActivity and production WebView. It prepares
Lessons browser, close-button focus and 120 CSS-pixel scroll through existing DOM handlers.
It never invokes `__restoreNativeUiSession`, writes fabricated restoration
metadata, replaces the WebViewClient, or repairs native/DOM focus after recreation.

1. `Activity.recreate()` creates a different Activity and WebView, with a new
   document time origin. The native-owned bootstrap restores the open panel,
   selected tab, exact scroll and DOM focus token.
2. After the replacement window actually becomes foreground, native WebView
   focus must already be present. Android Escape key dispatch closes the panel
   **before any content touch**; the stored projection records its dismissal.
3. Another `Activity.recreate()` keeps that panel closed.
4. A later owned document is loaded through a native WebView reload of the owned file document.
   The test opens the panel again and checks that its real writers store the
   projection. A third recreation restores it, then native Escape closes it
   without a preceding content touch.

Each passing sequence records six checkpoints, **three actual recreations** and
**two native Escape operations**. DOM setup is not a complete touch-driven user
journey. In particular, this does not validate game/engine persistence, a selected
lesson step, process death, OEM display transfer, camera clearance, TalkBack,
physical folding or signed-release behavior.

The fresh `NativeUi_Restore_20261105` AVD used Android API 36 and
`emulator-5590`. Its synthetic display override was 948×839 pixels at 400 dpi;
actual CSS viewport was **379×317 at DPR 2.5**. This is ordinary emulator geometry,
not a Samsung cover-display or cutout simulation. No other emulator or physical
device was selected. The emulator was stopped after verification.

## Safe reproduction

Prepare the project’s existing offline payload/build inputs using its normal
README workflow. This run copied the existing cached dependencies and identical
ignored inputs into the isolated worktree, then verified payload equality. Never
hand-edit generated web files or substitute moving canonical web main.

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME="$HOME/Library/Android/sdk"
cd android
./gradlew --offline --no-daemon :app:assembleDebug :app:assembleDebugAndroidTest \
  :app:testDebugUnitTest :app:lintDebug
cd ..
python3 scripts/check-native-restoration.py --serial emulator-5590 \
  --output build/native-restoration-new-run
```

Use a **fresh**, explicitly named `NativeUi_Restore_YYYYMMDD` AVD holding only
synthetic test data. Configure its compact test dimensions before the run. On a
fresh emulator, first acknowledge Android’s “Viewing full screen” onboarding for
the local debug app; the driver requires this precondition. That system dialog
took focus during an initial attempt, which was correctly rejected. No touch to
dismiss system UI is inserted into the passing restoration sequence.

The driver rejects physical-style serials before any ADB call, verifies the
AVD/QEMU identity, confirms accessibility services remain off, and inspects both
APK manifests. It requires the exact local debug package/test target and rejects
network/runtime permissions. Only then does it install the debug/test APKs and
clear **that target’s synthetic data**. Existing evidence directories are refused.
The native checks independently require explicit opt-in, emulator hardware,
debug target identity and no network permission before opening an Activity.
Missing opt-in and a physical-style serial were both observed to fail safely.
Do not bypass these guards or point them at an emulator containing personal data.
No permissions, audio, TalkBack, providers, network requests or model operations
are part of this sequence. Tests use public `evaluateJavascript` and native key
injection; no new debugging switch or JavaScript interface was introduced.

## Other checks and limits

Debug/test assembly passed; existing JVM suite: **13 tests passed**.
Final lint: **0 errors / 0 warnings**. Production payload hashes
are unchanged. Browser tests and prior signed/native/phone receipts retain their
own scope and were not rerun or reclassified as emulator acceptance.
