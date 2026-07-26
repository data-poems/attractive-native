# NEXT — Strangely Attractive + portfolio handoff

Continued from `LAST.md` (portfolio session, aborted on usage limit). No prior `NEXT.md` existed; this file is the living queue.

Updated: July 21, 2026.

## Attractive (this repo) — agent-side DONE

Closed-testing pack is ready for Console upload.

| Item | Status |
|------|--------|
| Package `attractive.lukesteuber.android` 1.0.0 (1) AAB/APK | Shelved under `artifacts/google-play/` |
| Listing, icon, feature graphic, phone + 7" tablet screenshots | In `play/` |
| Data safety / content rating / access worksheets | In `play/app-content/` |
| Web app at https://dr.eamer.dev/attractive/ | **Restored** |
| Dual-platform privacy at https://dr.eamer.dev/attractive/privacy.html | **Deployed** (iPhone/iPad/widgets + Android) |
| Binary unchanged | Version code 1 still correct |

Canonical materials: `play/` (not the read-only shelf snapshot — that freeze still lists the old privacy blocker in `manifest.json`).

### Your Console steps (Attractive)

1. Upload `artifacts/google-play/closed-testing/attractive.lukesteuber.android/1.0.0-1/app-bundle/strangely-attractive-1.0.0-1-mobile.aab` to Closed testing.
2. Paste listing from `play/listing/en-US.md`; upload graphics + screenshots per `play/screenshots.md`.
3. Data safety: answer **No** collected/shared data; privacy URL `https://dr.eamer.dev/attractive/privacy.html`.
4. Add closed-test emails / Google Group; paste `play/what-to-test.md` and `play/release-notes/en-US.txt`.
5. Start the closed test.

Full sequence: `play/closed-testing-checklist.md`.

## Portfolio leftovers (from LAST.md)

### Waiting on you (Console)

1. **PulseTime / Ambient Classic / Ambient Digital** — Advanced settings → Form factors → Add Wear OS → dedicated Wear track, then upload shelved Wear bundles. PulseTime phone AAB goes in the mobile track.
2. Upload other ready closed-testing bundles: Ambient mobile, Skymarshal, Quantified Mind, Attractive; define tester lists.
3. **Screenshat signing** — Play app-signing key `6C:A3…` vs live public APK `C8:1C…`. Decide: ask Google to replace app-signing key with C8 lineage, or accept split lineage. Do not upload until decided.

### Agent-side next (priority order)

1. **AltText code 9** — layout verified on emulator; still needs a real-device dark-theme phone **result** screenshot on Pixel 9a (`play/code9-do-not-submit.md`). Pixel 9a was not on ADB at last check (Pixel 10 + Pixel Watch 2 only). Plug in 9a → capture `03-result` → clear the gate file.
2. **Geepers evidence** — settings/insets + mic-granted shots now exist under `geepers-app/play/evidence/code-10001-screenshots/`; confirm the pack is complete, then upload 10001.
3. Listing packs for Skymarshal / Quantified Mind / PulseTime if still thin vs AltText.
4. Held dirty trees: Diachronica, Orrery, Idea Tiles — wait for clean worktrees.
5. Jankify — Play-safe build (no updater) + platform-neutral privacy; shelf AAB.
6. StoryBlocks — reserved, no action.

### Submitted / waiting

- What Color 1.0.2 (3) — Closed testing Alpha, in Google review.

## Product notes (Attractive, non-blocking)

- Bundled UI still brands as “Attractor Playground” / “Attractive” while the store name is “Strangely Attractive” — cosmetic.
- Some in-app dataset labels may still say “live”; Android does not fetch them. Soften later if reviewers flag it.
- PNG export via WebView download may be flaky — don’t oversell in tester notes.
