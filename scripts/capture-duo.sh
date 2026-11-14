#!/bin/bash
# Capture App Store screenshots of Strangely Attractive on an iPhone Duo
# simulator, outer or inner display, with no taps.
#
#   scripts/capture-duo.sh <udid> <outer|inner> <outdir> [path/to/Attractive.app]
#
# - outer: the folded phone's cover display (simctl --display=1), 1398x2034.
# - inner: the open phone's main display (simctl --display=LCD-1), 2007x2853
#   in portrait or 2853x2007 in landscape. Unfold the simulator in Device Hub
#   first; the script refuses to run while LCD-1 is inactive.
#
# Each screen is picked with launch arguments, which land in the app's
# UserDefaults argument domain (no app code reads them specially):
#   attractorRaw, viewModeRaw, hue, sensitiveDependence, showLyapunov,
#   hasSeenIntro (skips the intro tour) and duo.panel (Tune or Math in the
#   inner display's control pane).
#
# Every capture is checked for size and for a blank or black frame, and that
# the app is still running; then its alpha channel is flattened onto white.
# A failed check stops the script with a non-zero exit.
#
# If an .app is given it is installed first; otherwise the installed copy is
# used. CAPTURE_WAIT (seconds, default 12) sets how long each screen runs
# before the capture, so the trail fills in.
set -euo pipefail

BUNDLE_ID=com.lukesteuber.attractive
WAIT="${CAPTURE_WAIT:-12}"

usage() { echo "usage: $0 <udid> <outer|inner> <outdir> [path/to/Attractive.app]" >&2; exit 2; }
[ $# -ge 3 ] && [ $# -le 4 ] || usage
UDID="$1"; MODE="$2"; OUTDIR="$3"; APP="${4:-}"

case "$MODE" in
  outer) DISPLAY_ARG=1;     DISPLAY_NAME=LCD ;;
  inner) DISPLAY_ARG=LCD-1; DISPLAY_NAME=LCD-1 ;;
  *) usage ;;
esac

command -v magick >/dev/null || { echo "ImageMagick (magick) is required." >&2; exit 1; }
xcrun simctl list devices | grep -q "($UDID) (Booted)" \
  || { echo "Simulator $UDID is not booted." >&2; exit 1; }

# The display to capture must be the active one: the outer while folded,
# LCD-1 while open.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
xcrun devicectl device info displays --device "$UDID" --json-output "$TMP/displays.json" >/dev/null 2>&1 \
  || { echo "devicectl could not read the displays of $UDID." >&2; exit 1; }
ACTIVE="$(/usr/bin/python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
want = sys.argv[2]
print(any(x.get("name") == want and x.get("active") for x in d["result"]["displays"]))
' "$TMP/displays.json" "$DISPLAY_NAME")"
if [ "$ACTIVE" != True ]; then
  if [ "$MODE" = inner ]; then
    echo "LCD-1 is not active: unfold the simulator in Device Hub, then run this again." >&2
  else
    echo "The outer display is not active: close the simulator in Device Hub, then run this again." >&2
  fi
  exit 1
fi

if [ -n "$APP" ]; then
  [ -d "$APP" ] || { echo "No app bundle at $APP." >&2; exit 1; }
  xcrun simctl install "$UDID" "$APP"
fi
xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" app >/dev/null 2>&1 \
  || { echo "$BUNDLE_ID is not installed on $UDID; pass the .app path." >&2; exit 1; }

mkdir -p "$OUTDIR"

size_ok() {
  case "$MODE:$1" in
    outer:1398x2034) return 0 ;;
    inner:2007x2853|inner:2853x2007) return 0 ;;
  esac
  return 1
}

capture() {
  local name="$1"; shift
  local raw="$TMP/$name.png" out="$OUTDIR/$name.png"
  echo "== $name ($MODE)"
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" -hasSeenIntro YES "$@" >/dev/null
  sleep "$WAIT"
  xcrun simctl io "$UDID" screenshot --display="$DISPLAY_ARG" "$raw" >/dev/null 2>&1 \
    || { echo "Screenshot of display $DISPLAY_ARG failed." >&2; exit 1; }

  local size spread
  size="$(magick identify -format '%wx%h' "$raw")"
  size_ok "$size" || { echo "$name: $size is the wrong size for the $MODE display; refusing it." >&2; exit 1; }
  # A black or blank display is one flat color: its standard deviation is ~0.
  spread="$(magick "$raw" -colorspace Gray -format '%[fx:standard_deviation]' info:)"
  awk -v s="$spread" 'BEGIN { exit !(s >= 0.02) }' \
    || { echo "$name: the frame is blank or black (spread $spread); refusing it." >&2; exit 1; }
  xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep -q "UIKitApplication:$BUNDLE_ID" \
    || { echo "$name: the app is not running (crashed?); refusing the capture." >&2; exit 1; }

  magick "$raw" -background white -alpha remove -alpha off "$out"
  echo "   $out $size spread $spread"
}

# The screens. Every look setting is passed each time, so earlier runs can't
# leak in. Same arguments on both displays; duo.panel only shows on the inner
# display's control pane.
#   1. Lorenz in 3D with the default look.
#   2. Chen in 3D with both chaos lenses (separation and Lyapunov readout).
#   3. Thomas in 2D, orange; the inner pane shows Math (its equations).
capture 01-lorenz-3d     -attractorRaw lorenz -viewModeRaw scene3D -didMigrateViewModeTo3D YES \
                         -hue 0.55 -glow YES -zoom 1.0 \
                         -sensitiveDependence NO -showLyapunov NO -duo.panel Tune
capture 02-chen-chaos    -attractorRaw chen -viewModeRaw scene3D -didMigrateViewModeTo3D YES \
                         -hue 0.9 -glow NO -zoom 1.0 \
                         -sensitiveDependence YES -showLyapunov YES -duo.panel Tune
capture 03-thomas-2d     -attractorRaw thomas -viewModeRaw canvas2D -didMigrateViewModeTo3D YES \
                         -hue 0.08 -glow YES -zoom 1.8 \
                         -sensitiveDependence NO -showLyapunov NO -duo.panel Math

echo "DONE: 3 $MODE screenshots in $OUTDIR"
