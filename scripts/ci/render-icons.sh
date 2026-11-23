#!/usr/bin/env bash
# Renders design/icon/nocchi-icon.svg (full-bleed artwork) into:
#   - macOS AppIcon set: 824px rounded tile with soft shadow on a transparent 1024 canvas, 16–1024 px
#   - iOS AppIcon: opaque full-bleed 1024 px (iOS applies its own mask)
# The SVG is the single source of truth; the PNGs are generated in CI and not committed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/design/icon/nocchi-icon.svg"
WORK="$(mktemp -d)"
MAC="$ROOT/macOS/Nocchi/Resources/Assets.xcassets/AppIcon.appiconset"
IOS="$ROOT/iOS/Nocchi/Resources/Assets.xcassets/AppIcon.appiconset"

if ! command -v rsvg-convert >/dev/null 2>&1; then
  brew install librsvg
fi

python3 - "$SRC" "$WORK/mac.svg" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
start = text.index(">", text.index("<svg")) + 1
end = text.rindex("</svg>")
inner = text[start:end]
wrapped = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">\n'
    '  <defs>\n'
    '    <clipPath id="macTile"><rect x="100" y="100" width="824" height="824" rx="184"/></clipPath>\n'
    '    <filter id="macShadow" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="14"/></filter>\n'
    '  </defs>\n'
    '  <rect x="100" y="114" width="824" height="824" rx="184" fill="#000" fill-opacity="0.32" filter="url(#macShadow)"/>\n'
    '  <g clip-path="url(#macTile)"><g transform="translate(100 100) scale(0.8046875)">'
    + inner +
    '</g></g>\n'
    '  <rect x="101" y="101" width="822" height="822" rx="183" fill="none" stroke="#000" stroke-opacity="0.28" stroke-width="2"/>\n'
    '</svg>\n'
)
open(dst, "w", encoding="utf-8").write(wrapped)
PY

mkdir -p "$MAC" "$IOS"
for spec in \
  "16:icon_16x16.png" "32:icon_16x16@2x.png" \
  "32:icon_32x32.png" "64:icon_32x32@2x.png" \
  "128:icon_128x128.png" "256:icon_128x128@2x.png" \
  "256:icon_256x256.png" "512:icon_256x256@2x.png" \
  "512:icon_512x512.png" "1024:icon_512x512@2x.png"; do
  px="${spec%%:*}"
  name="${spec#*:}"
  rsvg-convert -w "$px" -h "$px" "$WORK/mac.svg" -o "$MAC/$name"
done

# iOS: opaque, no alpha channel (App Store requirement) — flatten through JPEG.
rsvg-convert -w 1024 -h 1024 -b "#120d0b" "$SRC" -o "$WORK/ios.png"
sips -s format jpeg -s formatOptions 100 "$WORK/ios.png" --out "$WORK/ios.jpg" >/dev/null
sips -s format png "$WORK/ios.jpg" --out "$IOS/icon-1024.png" >/dev/null

echo "Rendered icons:"
ls -la "$MAC" "$IOS"
echo "::notice title=Icons::Rendered AppIcon sets from design/icon/nocchi-icon.svg"
