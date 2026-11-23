#!/usr/bin/env bash
# Renders design/icon/nocchi-icon.svg (macOS tile: 824px rounded square on a 1024 canvas) into:
#   - macOS AppIcon set, 16–1024 px, straight from the source
#   - iOS AppIcon: opaque full-bleed 1024 px derived from the same artwork (iOS applies its own mask)
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

python3 - "$SRC" "$WORK/ios.svg" <<'PY'
# iOS 需要满版方图（系统自己加圆角）：把圆角瓷砖铺满整张画布，去掉瓷砖阴影与描边，
# 再把视口稍微放大，让「冲出画框」的相片顶部也能留在画面里。
import re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
text = re.sub(r'\s*<rect id="tileShadow"[^>]*/>', "", text)
text = re.sub(r'\s*<rect id="tileStroke"[^>]*/>', "", text)
text = re.sub(r'<rect id="tileBg"[^>]*/>', '<rect id="tileBg" x="0" y="0" width="1024" height="1024" fill="url(#room)"/>', text)
text = re.sub(r'<rect id="tileClipRect"[^>]*/>', '<rect id="tileClipRect" x="0" y="0" width="1024" height="1024"/>', text)
text = text.replace('viewBox="0 0 1024 1024"', 'viewBox="64 40 896 896"', 1)
open(dst, "w", encoding="utf-8").write(text)
PY

mkdir -p "$MAC" "$IOS"
# macOS：源文件本身就是 824px 圆角瓷砖 + 阴影（与 macOS 图标网格一致）。
for spec in \
  "16:icon_16x16.png" "32:icon_16x16@2x.png" \
  "32:icon_32x32.png" "64:icon_32x32@2x.png" \
  "128:icon_128x128.png" "256:icon_128x128@2x.png" \
  "256:icon_256x256.png" "512:icon_256x256@2x.png" \
  "512:icon_512x512.png" "1024:icon_512x512@2x.png"; do
  px="${spec%%:*}"
  name="${spec#*:}"
  rsvg-convert -w "$px" -h "$px" "$SRC" -o "$MAC/$name"
done

# iOS: opaque, no alpha channel (App Store requirement) — flatten through JPEG.
rsvg-convert -w 1024 -h 1024 -b "#1b0c08" "$WORK/ios.svg" -o "$WORK/ios.png"
sips -s format jpeg -s formatOptions 100 "$WORK/ios.png" --out "$WORK/ios.jpg" >/dev/null
sips -s format png "$WORK/ios.jpg" --out "$IOS/icon-1024.png" >/dev/null

echo "Rendered icons:"
ls -la "$MAC" "$IOS"
echo "::notice title=Icons::Rendered AppIcon sets from design/icon/nocchi-icon.svg"
