#!/bin/bash
# Renders Resources/Icon/AppIcon.svg into Resources/AppIcon.icns,
# Resources/DMG/background.svg into Resources/DMG/background.tiff, and
# docs/hero.html into docs/hero.png.
#
# Run it after changing any of them; the outputs are committed, so building
# Perch doesn't depend on this.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swiftc -O -o "$WORK/render-svg" scripts/render-svg.swift

ICONSET="$WORK/AppIcon.iconset"
mkdir "$ICONSET"
for points in 16 32 128 256 512; do
    "$WORK/render-svg" Resources/Icon/AppIcon.svg 1024 1024 "$points" "$ICONSET/icon_${points}x${points}.png"
    "$WORK/render-svg" Resources/Icon/AppIcon.svg 1024 1024 "$((points * 2))" "$ICONSET/icon_${points}x${points}@2x.png"
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"

# One tiff holding the background at 1x and 2x, so it's sharp on any display.
"$WORK/render-svg" Resources/DMG/background.svg 660 400 660 "$WORK/background.png"
"$WORK/render-svg" Resources/DMG/background.svg 660 400 1320 "$WORK/background@2x.png"
tiffutil -cathidpicheck "$WORK/background.png" "$WORK/background@2x.png" -out Resources/DMG/background.tiff 2>/dev/null
echo "Wrote Resources/DMG/background.tiff"

# The readme's hero, at 2x.
"$WORK/render-svg" docs/hero.html 1280 640 2560 docs/hero.png
echo "Wrote docs/hero.png"
