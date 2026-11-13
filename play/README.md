# Google Play handoff

Tracked source materials for Strangely Attractive's Google Play listing live here.

## Current state (November 12, 2026)

- Package: `attractive.lukesteuber.android`
- Candidate: 1.0.7 (8), built from this tree. Not signed for release, not uploaded, not tested on a physical
  device.
- Nothing has been published on Google Play. The July closed-testing pack for 1.0.0 (1) was staged but its
  bundle has the faults listed below, so it should not be used.
- Form factors: Android phone and tablet
- Price: Free
- Category: Education

The app has no direct-download updater, account system, advertising, analytics, network permission, or remote
asset dependency, so the same bundle serves Google Play and the direct download.

## Why 1.0.0 to 1.0.5 should not go to Play

Checked on emulators in November 2026:

- The 3D view was drawn at the pixel-buffer size, so on any phone or tablet the picture sat in a corner of a
  mostly black screen. Every guided lesson uses that view.
- Export as PNG did nothing.
- The app described its data themes as real-world and live data.
- It shipped three.js, Rough.js, KaTeX and the KaTeX fonts without their license texts.

1.0.6 (7) fixed those. 1.0.7 (8) adds sharper 2D drawing and accessibility fixes found with TalkBack and large
text. Both need the web app commits described in the root README.

## Files

| File | What |
|---|---|
| `listing/en-US.md` | Store text for 1.0.7 (8) |
| `release-notes/en-US.txt` | Release notes |
| `screenshots.md`, `assets/screenshots/` | Screenshots of 1.0.7 (8) and their alt text |
| `assets/graphics/`, `build-assets.sh` | Icon and feature graphic made in July from the iOS icon. Not regenerated |
| `app-content/` | Answers for the Console's App content forms |
| `policy/` | Source of the published privacy policy |
| `closed-testing-checklist.md` | Upload sequence |
| `what-to-test.md` | Tester instructions |
| `validation.md` | What was checked, for 1.0.7 (8) and, below it, the July record for 1.0.0 (1) |

## URLs

- Web app: `https://dr.eamer.dev/attractive/`
- Privacy policy: `https://dr.eamer.dev/attractive/privacy.html` (covers iOS and Android; source
  `policy/privacy-policy.html`; effective November 12, 2026)

Follow `closed-testing-checklist.md` for the upload sequence.
