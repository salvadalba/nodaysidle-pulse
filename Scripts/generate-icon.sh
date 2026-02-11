#!/usr/bin/env bash
# generate-icon.sh — Create AppIcon.icns from Resources/logo.svg
# Requires: rsvg-convert (brew install librsvg)

set -e
cd "$(dirname "$0")/.."
ICONSET=".build/AppIcon.iconset"
mkdir -p "$ICONSET"

echo "Generating icon from Resources/logo.svg…"
for size in 16 32 64 128 256 512; do
  rsvg-convert -w $size -h $size Resources/logo.svg -o "$ICONSET/icon_${size}x${size}.png"
  rsvg-convert -w $((size*2)) -h $((size*2)) Resources/logo.svg -o "$ICONSET/icon_${size}x${size}@2x.png"
done

iconutil -c icns "$ICONSET" -o .build/AppIcon.icns
echo "Created .build/AppIcon.icns"
