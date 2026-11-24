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
export NOCCHI_SCREENSHOT_SAMPLES="$ROOT/design/screenshots/samples"

# 跑一遍截图工作室：run_pass <输出目录> <日志> [给 App 的额外参数…]
run_pass() {
  local out="$1" log="$2"
  shift 2
  mkdir -p "$out"
  export NOCCHI_LIBRARY_ROOT="${RUNNER_TEMP:-/tmp}/nocchi-screenshot-library-$(basename "$out")"
  rm -rf "$NOCCHI_LIBRARY_ROOT"
  "$APP/Contents/MacOS/Nocchi" --render-screenshots "$out" "$@" > "$log" 2>&1 &
  local pid=$!
  # 正常两三分钟；最多等 9 分钟（App 自己 8 分钟就会放弃）。
  for _ in $(seq 1 540); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "$pid" 2>/dev/null; then
    echo "::error title=Screenshots::The screenshot studio did not finish in 9 minutes ($out)"
    kill "$pid" 2>/dev/null || true
  fi
  wait "$pid"
  local status=$?
  grep -E "^(SHOT|STUDIO)" "$log" | while IFS= read -r line; do
    echo "::notice title=Screenshots::${line}"
  done
  ls -la "$out"
  return $status
}

# 中文界面（默认）；再用英文界面拍一遍（文档站英文页用，也顺便验收翻译）。
run_pass "$OUT" "$LOG"
STATUS=$?
run_pass "$OUT/en" "${LOG%.log}-en.log" -app.language en -AppleLanguages "(en)"
EN_STATUS=$?

COUNT=$(find "$OUT" -maxdepth 1 -name "*.jpg" | wc -l | tr -d ' ')
EN_COUNT=$(find "$OUT/en" -maxdepth 1 -name "*.jpg" | wc -l | tr -d ' ')
if [ "$COUNT" -lt 1 ]; then
  echo "::error title=Screenshots::No screenshots were written (studio exit ${STATUS})"
  tail -n 40 "$LOG"
  exit 1
fi
if [ "$EN_COUNT" -lt 1 ]; then
  echo "::warning title=Screenshots::No English screenshots were written (studio exit ${EN_STATUS})"
  tail -n 40 "${LOG%.log}-en.log"
fi
echo "::notice title=Screenshots::${COUNT} screenshots, ${EN_COUNT} in English (studio exit ${STATUS} / ${EN_STATUS})"
