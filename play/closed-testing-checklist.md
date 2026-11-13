# Closed-testing checklist

For 1.0.7 (8). Boxes are ticked only for what has been done for this version.

## Package

- [x] Package is `attractive.lukesteuber.android`.
- [x] Version name is 1.0.7 and version code is 8.
- [x] Minimum SDK is 26 and target SDK is 36.
- [x] No direct-update mechanism; no Play-specific build is needed.
- [x] Unit tests, release lint, the browser test of the adapter and the instrumented restoration checks pass.
- [ ] Build the bundle with the Strangely Attractive release certificate
      (`E1:1E:26:88:C8:F3:06:72:6D:3A:45:3B:D0:CE:D5:5D:A6:A0:5A:91:CC:B9:4B:98:B7:90:A9:34:20:DE:45:C1`).
- [ ] Install the signed build on a physical phone and tablet.
- [ ] Upload the AAB to a closed-testing release in Play Console.

## Store listing

- [x] Listing and release copy match 1.0.7 (8).
- [x] Phone, 7-inch and 10-inch screenshots of 1.0.7 (8) with alt text.
- [x] Screenshots reviewed: real captures, no device frames, no added text.
- [ ] Decide the icon and feature graphic. `assets/graphics/` holds the July pair made from the iOS icon; the
      Android launcher icon is different art.
- [x] Privacy policy at `https://dr.eamer.dev/attractive/privacy.html` mentions Export as PNG (effective
      November 12, 2026).

## App content

- [x] App access requires no credentials.
- [x] Data safety worksheet: no collected or shared data.
- [x] Content-rating notes prepared.
- [x] Target audience recommendation prepared.
- [x] Ads declaration prepared: No ads.
- [x] Price prepared: Free, with no in-app products.

## Release

- [ ] Add the closed-test email list or Google Group.
- [ ] Paste `what-to-test.md` into the tester instructions.
- [ ] Paste the release notes from `release-notes/en-US.txt`.
- [ ] Review Play's automated device and policy checks.
- [ ] Start the closed test.
