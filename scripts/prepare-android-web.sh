#!/usr/bin/env bash
# File Purpose: Build an offline web asset tree for the Attractive Android WebView shell.
# Primary Components: Copy attractive-web, rewrite CDN tags to vendored libs, drop analytics.
# Inputs/Outputs: Reads ../attractive-web; writes ../android/web (APK asset source).

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SRC="${ROOT}/attractive-web"
OUT="${ROOT}/android/web"

if [[ ! -f "${SRC}/index.html" ]]; then
  echo "Missing ${SRC}/index.html — place the Attractive web app at attractive-web/." >&2
  exit 1
fi
if [[ ! -f "${SRC}/vendor/three.min.js" ]]; then
  echo "Missing vendored three.js at ${SRC}/vendor/three.min.js" >&2
  echo "Run the vendor bootstrap once (see android/README.md)." >&2
  exit 1
fi

rm -rf "${OUT}"
mkdir -p "${OUT}"

# Core app files only — no docs/README/social card required at runtime.
for name in \
  index.html style.css main.js onboarding.js \
  attractive-3d.js attractive-lyapunov.js attractive-equations.js \
  attractive-inspect.js attractive-lessons.js
do
  cp "${SRC}/${name}" "${OUT}/${name}"
done
cp -R "${SRC}/vendor" "${OUT}/vendor"
cp "${ROOT}/android/compact-window.css" "${OUT}/compact-window.css"
cp "${ROOT}/android/accessibility.js" "${OUT}/accessibility.js"

OUT="${OUT}" python3 - <<'PY'
from pathlib import Path
import os, re

out = Path(os.environ["OUT"])
html_path = out / "index.html"
html = html_path.read_text(encoding="utf-8")
html = html.replace('</head>', '  <link rel="stylesheet" href="compact-window.css">\n</head>')
# Register the adapter's bubbling Space guard before main.js registers its
# global shortcut. This preserves target key handlers and native activation.
main_script = '<script src="main.js"></script>'
if html.count(main_script) != 1:
    raise SystemExit("Expected exactly one main.js script for accessibility adapter")
html = html.replace(main_script, '<script src="accessibility.js"></script>\n  ' + main_script)

# Drop remote font preconnect/stylesheet — use system fonts offline.
html = re.sub(
    r'\s*<!-- Preload critical font -->.*?</link>\s*',
    "\n  <!-- Offline shell: system fonts only -->\n",
    html,
    count=1,
    flags=re.S,
)
# Fallback if comment text differs
html = re.sub(
    r'\s*<link rel="preconnect" href="https://fonts\.googleapis\.com">\s*',
    "\n",
    html,
)
html = re.sub(
    r'\s*<link rel="preconnect" href="https://fonts\.gstatic\.com"[^>]*>\s*',
    "\n",
    html,
)
html = re.sub(
    r'\s*<link href="https://fonts\.googleapis\.com/css2\?[^"]*" rel="stylesheet">\s*',
    "\n",
    html,
)

# Vendor CDN scripts/styles.
replacements = [
    (
        r'<script src="https://cdn\.jsdelivr\.net/npm/roughjs@[^"]+"></script>',
        '<script src="vendor/rough.min.js"></script>',
    ),
    (
        r'<link rel="stylesheet" href="https://cdn\.jsdelivr\.net/npm/katex@[^"]+">',
        '<link rel="stylesheet" href="vendor/katex/katex.min.css">',
    ),
    (
        r'<script defer src="https://cdn\.jsdelivr\.net/npm/katex@[^"]+"></script>',
        '<script defer src="vendor/katex.min.js"></script>',
    ),
    (
        r'<script src="https://cdn\.jsdelivr\.net/npm/three@[^"]+"></script>',
        '<script src="vendor/three.min.js"></script>',
    ),
]
for pattern, repl in replacements:
    html, n = re.subn(pattern, repl, html, count=1)
    if n != 1:
        raise SystemExit(f"Failed to rewrite CDN tag matching {pattern}")

# Absolute site favicon is useless offline; keep data-URI favicon only.
html = re.sub(
    r'\s*<link rel="icon" type="image/x-icon" href="/assets/images/favicon\.ico">\s*',
    "\n",
    html,
)

# No analytics in the offline APK.
html = re.sub(
    r'\s*<!-- GoatCounter Analytics -->.*?</script>\s*',
    "\n",
    html,
    count=1,
    flags=re.S,
)

# Guard: no remaining remote script/style loads (ignore data: and xmlns).
remote = re.findall(
    r'<(?:script|link)\b[^>]*\b(?:src|href)=["\']https?://[^"\']+["\'][^>]*>',
    html,
    flags=re.I,
)
if remote:
    raise SystemExit("Offline index still references remote script/link URLs:\n" + "\n".join(remote))

html_path.write_text(html, encoding="utf-8")

# Prefer system UI fonts offline (style.css imports Inter via Google in some builds —
# the HTML link is removed; CSS font-family still lists Inter with fallbacks).
css_path = out / "style.css"
css = css_path.read_text(encoding="utf-8")
css = css.replace(
    "font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
    "font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif",
)
css = css.replace(
    'font-family: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    "font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif",
)
css_path.write_text(css, encoding="utf-8")
print(f"Prepared offline web assets in {out}")
PY
