# License texts shown inside the Android app

`scripts/prepare-android-web.sh` builds `third-party-notices.html` from these
files and links it from the About dialog. They cover the libraries that
`scripts/vendor-web-libs.sh` downloads and the build copies into the app.

| File | Covers | Source |
|------|--------|--------|
| `three.js-LICENSE.txt` | three.js 0.149.0 | `LICENSE` in the npm package `three@0.149.0` |
| `roughjs-LICENSE.txt` | Rough.js 4.6.6 | `LICENSE` in the npm package `roughjs@4.6.6` |
| `katex-LICENSE.txt` | KaTeX 0.16.11 JavaScript and CSS | `LICENSE` in the npm package `katex@0.16.11` |
| `katex-fonts-OFL.txt` | KaTeX 0.16.11 fonts (WOFF2) | copyright and reserved-name notices from the fonts' name tables, followed by the SIL Open Font License 1.1 text |

When a library version changes in `scripts/vendor-web-libs.sh`, replace its
file here from the new package and update `NOTICE.md`.
