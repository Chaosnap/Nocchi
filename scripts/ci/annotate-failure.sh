#!/usr/bin/env bash
# Usage: annotate-failure.sh <log-file> <title>
#
# 把失败日志中的错误行和日志尾部写成一条 GitHub Actions error 注解。
# 公开仓库的 Check Run 注解可以通过 REST API 匿名读取，
# 这样不登录、不下载日志也能看到编译错误。
set -uo pipefail

LOG="${1:-}"
TITLE="${2:-CI failure}"

if [[ -z "$LOG" || ! -f "$LOG" ]]; then
  echo "::error title=${TITLE}::(log file not found: ${LOG})"
  exit 0
fi

ERRORS="$(grep -E "error:|error\[|fatal error|Fatal error|failed|FAILED|✖|Assertion|XCTAssert|Spec validation|Decoding failed" "$LOG" | grep -v "warning:" | head -n 60 || true)"
TAIL="$(tail -n 60 "$LOG")"

emit() {
  local title="$1" body="$2"
  # 工作流命令转义：% → %25，\r → %0D，\n → %0A
  local escaped
  escaped="$(printf '%s' "$body" | sed -e 's/%/%25/g' -e 's/\r/%0D/g' | awk 'BEGIN{ORS="%0A"} {print}')"
  echo "::error title=${title}::${escaped}"
}

if [[ -n "$ERRORS" ]]; then
  emit "${TITLE} · error lines" "$ERRORS"
fi
emit "${TITLE} · log tail" "$TAIL"
exit 0
