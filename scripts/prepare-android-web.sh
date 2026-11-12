#!/usr/bin/env bash
# File Purpose: Build an offline web asset tree for the Attractive Android WebView shell.
# Primary Components: Copy attractive-web, rewrite CDN tags to vendored libs, drop analytics,
#   build the third-party notices page from android/notices.
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

OUT="${OUT}" NOTICES="${ROOT}/android/notices" python3 - <<'PY'
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

# Third-party notices: the app ships three.js, Rough.js, KaTeX and the KaTeX
# fonts, so their license texts ship with it and About links to them.
import html as html_escape

notices_dir = Path(os.environ["NOTICES"])
notice_sections = [
    ("three.js 0.149.0", "3D view", "three.js-LICENSE.txt"),
    ("Rough.js 4.6.6", "hand-drawn drawing styles", "roughjs-LICENSE.txt"),
    ("KaTeX 0.16.11", "equation typesetting (JavaScript and CSS)", "katex-LICENSE.txt"),
    ("KaTeX fonts 0.16.11", "equation fonts", "katex-fonts-OFL.txt"),
]
parts = []
for title, use, filename in notice_sections:
    text = (notices_dir / filename).read_text(encoding="utf-8").strip()
    if not text:
        raise SystemExit(f"Empty license text: {filename}")
    parts.append(
        f"  <section>\n    <h2>{html_escape.escape(title)}</h2>\n"
        f"    <p>Used for: {html_escape.escape(use)}.</p>\n"
        f"    <pre>{html_escape.escape(text)}</pre>\n  </section>"
    )
(out / "third-party-notices.html").write_text(
    """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Open-source notices</title>
  <style>
    html { background: #0a0a0a; color: #e8e8e8; }
    body { margin: 0 auto; padding: 16px; max-width: 760px; line-height: 1.5;
           font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif; }
    h1 { font-size: 1.4rem; margin: 12px 0; }
    h2 { font-size: 1.1rem; margin: 28px 0 4px; padding-top: 16px; border-top: 1px solid #333; }
    p { margin: 4px 0 12px; }
    pre { white-space: pre-wrap; overflow-wrap: anywhere; font-size: 0.85rem; margin: 0;
          font-family: ui-monospace, 'Roboto Mono', monospace; color: #c8c8c8; }
    button { min-height: 48px; min-width: 48px; padding: 0 20px; font: inherit; color: #0a0a0a;
             background: #00e5e5; border: 0; border-radius: 8px; }
    button:focus-visible { outline: 3px solid #fff; outline-offset: 2px; }
  </style>
</head>
<body>
  <button type="button" id="noticesBackBtn">Back</button>
  <h1>Open-source notices</h1>
  <p>Strangely Attractive includes the open-source software below. Each project's license follows.</p>
"""
    + "\n".join(parts)
    + """
  <script>
    document.getElementById('noticesBackBtn').addEventListener('click', function () {
      if (history.length > 1) history.back(); else location.href = 'index.html';
    });
  </script>
</body>
</html>
""",
    encoding="utf-8",
)
close_button = '<button id="modalCloseBtn" autofocus>Close</button>'
if html.count(close_button) != 1:
    raise SystemExit("Expected exactly one About close button for the notices link")
html = html.replace(
    close_button,
    '<h3>Open-Source Notices</h3>\n'
    '      <p><a href="third-party-notices.html">Licenses for three.js, Rough.js, KaTeX and the KaTeX fonts</a></p>\n\n'
    '      ' + close_button,
)

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
