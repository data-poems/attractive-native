# App Review: Strangely Attractive 1.1.0 (16), 14 November 2026

## What Apple said

Submitted 2026-11-14 11:14 PST (submission `67ed93a1-a0b1-401a-8633-8648dd229f52`).
Rejected 16:31 PST under **Guideline 2.1, App Completeness**, in an
automated message: "The app crashed on launch." It asks for testing on
physical devices running the latest OS. No crash log was attached.

## What I checked (napoleon, 2026-11-14 evening)

| Check | Result |
|---|---|
| Uploaded IPA (`sign/out/strangely-attractive-1.1.0-16/export/Attractive.ipa`, SHA-256 40be1866…ac1a) | iphoneos27.2 SDK (24B8118), min iOS 17.0, `UIApplicationSceneManifest` present, entitlements normal, no App Group (none is used), SwiftMath resource bundle present |
| iOS 27.1 APIs (`ArrangementView`, `ReservedRegion`, `reservedRegions`, `DeviceHinge`) | All **weak-import** in the device binary (`dyld_info -imports`), so they can't break dyld on an older OS |
| Release build from c2ae6a8, launched on simulators | Runs and draws the intro on iPhone 17 Pro iOS 27.2, iPad Pro 11" iOS 27.2, iPhone 17 Pro **iOS 26.5**, and iPhone Duo (iPhone19-4 runtime). **No crash** |
| SwiftMath version | 1.7.3 (fa8244e) in both the archive and the simulator build |
| TestFlight crash feedback / diagnostic signatures for build 16 | None |
| Launch-time force unwraps, `fatalError`, App Group or keychain use | None on the launch path |

**What's new in this build:** 1.1.0 (16) is the first Attractive build made
with the **iOS 27.2 SDK** (Xcode 27.2). The live 1.0.2 (15) was built with the
iOS 26 SDK (23F81a). The only code on the launch path that changed is
`detectsFold` (an `onGeometryChange` reserved-region query on the root view
for iOS 27.1+) and the layout swap it can trigger (`DuoLayout.swift`,
`ContentView.swift`).

## Cause

**Not found yet.** The crash doesn't happen in any simulator, including the
iOS 27.2 runtime here, which is a beta (24B5110a) and not the release build
devices run (24B8118). So it's either device-only (Metal/SceneKit on real
GPUs, or iOS 27.2 release behavior) or specific to a review device such as a
real iPhone Duo. Without a crash log, any code change would be a guess.

## Proposed fix (in order)

1. **Reproduce on a device (Luke).** 1.1.0 (16) is already in internal
   TestFlight testing. Install it on the iPhone and the iPad mini, then launch
   it cold: once fresh and once over 1.0.2.
   - If it crashes, TestFlight offers to send feedback. Send it, and I can read
     it with the API (`betaFeedbackCrashSubmissions`). Or AirDrop the
     `Attractive-*.ips` from Settings › Privacy & Security › Analytics &
     Improvements › Analytics Data. I'll symbolicate it against
     `sign/out/strangely-attractive-1.1.0-16/Attractive-16.xcarchive/dSYMs`
     and fix the actual line.
   - If it launches fine on both, the crash is specific to a review device
     (most likely the iPhone Duo or iOS 27.2 release on an iPhone 17). Then
     send the reply below, which asks Apple for the crash log.
2. **Fix, then build 1.1.0 (17)** from a new merge. Bump
   `CURRENT_PROJECT_VERSION` in `project.yml` to 17, copy
   `sign/strangely-attractive-1.1.0.sh` with the new pin and build, then have
   Luke run it in Terminal.app, attach build 17 and resubmit.
3. **Fallback if Apple sends no log and nothing reproduces:** ship a build 17
   that guards the one new launch-path query. Run `detectsFold` only after the
   first frame (for example, a `.task` that sets a flag before the
   `onGeometryChange` is attached), so the root view never swaps layouts
   during scene connection. This is a hedge, not a confirmed fix, so say so
   if Luke picks it.

## Draft: Resolution Center reply (ask for the log)

```
Hello,

Thank you for the review. I'm sorry the app crashed on launch. Strangely Attractive 1.1.0 (16) launches normally in my own testing, so I can't reproduce the crash yet. Could you share the crash log, along with the device model and iOS version it was tested on? That will let me find and fix the exact cause before I submit a corrected build.

Thank you.
```

## Draft: Resolution Center reply (with the fixed build)

```
Hello,

Thank you for the review and for reporting the launch crash. I found the cause: [one-line cause]. Build 1.1.0 (17) fixes it. I tested it on a physical [device] running iOS [version], launching it fresh and over the previous version, and it starts normally. Build 17 is now attached to this version for review.

Thank you.
```

## Needs Luke's yes (none of it done)

- Device test from TestFlight (step 1).
- Sending either reply.
- Any new build, upload or resubmission.

Simulators made for these checks: "AttrCheck iPhone 27.2", "AttrCheck iPad
27.2", "AttrCheck iPhone 26.5", "AttrCheck Duo". All are shut down and safe to
delete.
