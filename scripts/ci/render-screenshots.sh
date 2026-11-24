#!/usr/bin/env bash
# Usage: render-screenshots.sh <Nocchi.app> <output-dir>
#
# 在 GitHub Actions 上用截图模式启动 App（不开刘海、不注册快捷键），拍完自己退出。
# 照片库放在临时目录（NOCCHI_LIBRARY_ROOT），样片来自 design/screenshots/samples。
# 以 SHOT / STUDIO 开头的输出行写成注解，公开仓库不登录也能在运行页面上看到每张图的尺寸和拍法。
set -uo pipefail

APP="${1:?Nocchi.app path}"
OUT="${2:?output directory}"
LOG="${RUNNER_TEMP:-/tmp}/studio.log"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

mkdir -p "$OUT"
export NOCCHI_LIBRARY_ROOT="${RUNNER_TEMP:-/tmp}/nocchi-screenshot-library"
export NOCCHI_SCREENSHOT_SAMPLES="$ROOT/design/screenshots/samples"
rm -rf "$NOCCHI_LIBRARY_ROOT"

"$APP/Contents/MacOS/Nocchi" --render-screenshots "$OUT" > "$LOG" 2>&1 &
PID=$!

# 正常两三分钟；最多等 9 分钟（App 自己 8 分钟就会放弃）。
for _ in $(seq 1 540); do
  kill -0 "$PID" 2>/dev/null || break
  sleep 1
done
if kill -0 "$PID" 2>/dev/null; then
  echo "::error title=Screenshots::The screenshot studio did not finish in 9 minutes"
  kill "$PID" 2>/dev/null || true
fi
wait "$PID"
STATUS=$?

grep -E "^(SHOT|STUDIO)" "$LOG" | while IFS= read -r line; do
  echo "::notice title=Screenshots::${line}"
done
ls -la "$OUT"

COUNT=$(find "$OUT" -name "*.jpg" | wc -l | tr -d ' ')
if [ "$COUNT" -lt 1 ]; then
  echo "::error title=Screenshots::No screenshots were written (studio exit ${STATUS})"
  tail -n 40 "$LOG"
  exit 1
fi
echo "::notice title=Screenshots::${COUNT} screenshots (studio exit ${STATUS})"
