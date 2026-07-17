#!/usr/bin/env bash
# File Purpose: Download offline vendor libraries for attractive-web (and Android packaging).
# Primary Components: three.js, Rough.js, KaTeX JS/CSS + woff2 fonts.
# Inputs/Outputs: Writes attractive-web/vendor/.

set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
WEB="${ROOT}/attractive-web"
VENDOR="${WEB}/vendor"
FONT_DIR="${VENDOR}/katex/fonts"

if [[ ! -d "${WEB}" ]]; then
  echo "Missing ${WEB}" >&2
  exit 1
fi

mkdir -p "${FONT_DIR}"
curl -fsSL -o "${VENDOR}/three.min.js" "https://cdn.jsdelivr.net/npm/three@0.149.0/build/three.min.js"
curl -fsSL -o "${VENDOR}/rough.min.js" "https://cdn.jsdelivr.net/npm/roughjs@4.6.6/bundled/rough.min.js"
curl -fsSL -o "${VENDOR}/katex.min.js" "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"
curl -fsSL -o "${VENDOR}/katex/katex.min.css" "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css"

python3 - <<PY
from pathlib import Path
import re, urllib.request

css_path = Path("${VENDOR}/katex/katex.min.css")
font_dir = Path("${FONT_DIR}")
css = css_path.read_text()
names = sorted(set(re.findall(r"url\(fonts/([^)]+\.woff2)\)", css)))
base = "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/fonts/"
for name in names:
    dest = font_dir / name
    if not dest.exists():
        urllib.request.urlretrieve(base + name, dest)
        print("fetched", name)
# Drop non-woff2 face sources to keep the APK smaller.
css = re.sub(r"url\(fonts/[^)]+\.(?:woff|ttf|otf)\)\s*format\([^)]+\)\s*,?\s*", "", css)
css = re.sub(r",\s*}", "}", css)
css_path.write_text(css)
print(f"vendor ready at {Path('${VENDOR}')} ({len(names)} woff2 fonts)")
PY
