#!/usr/bin/env bash
set -euo pipefail

PLAY_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$PLAY_DIR/.." && pwd)"
GRAPHICS_DIR="$PLAY_DIR/assets/graphics"
MASTER="$PROJECT_DIR/Attractive/Assets.xcassets/AppIcon.appiconset/icon-strange-attractor-1024.png"
FONT="/System/Library/Fonts/SFNS.ttf"

mkdir -p "$GRAPHICS_DIR"

magick "$MASTER" -resize 512x512 -alpha off "$GRAPHICS_DIR/app-icon-512.png"

magick "$MASTER" -resize 1024x1024^ -gravity center -crop 1024x500+0+0 +repage \
  \( -size 1024x500 gradient:'#05050ff0-#05050f08' \) -compose over -composite \
  -font "$FONT" -gravity northwest -fill '#ffffff' -pointsize 72 \
  -annotate +58+120 'Strangely' \
  -fill '#72e6ee' -annotate +58+205 'Attractive' \
  -fill '#d7d9e4' -pointsize 30 \
  -annotate +62+310 'Twenty-five paths into chaos.' \
  -alpha remove -alpha off \
  "$GRAPHICS_DIR/feature-graphic-1024x500.png"

identify "$GRAPHICS_DIR/app-icon-512.png"
identify "$GRAPHICS_DIR/feature-graphic-1024x500.png"
