#!/usr/bin/env bash
set -euo pipefail

# usage:
#   ./scripts/route.sh '@chulclebot [ROLE=planner] 배포 계획 짜줘'
#   ./scripts/route.sh '@chulclebot [TASK_ID=abc-1] 테스트 결과 요약해줘'

RAW="${*:-}"
[[ -n "$RAW" ]] || { echo "[ERR] message required"; exit 1; }

ROLE=""
TASK_ID=""

if [[ "$RAW" =~ \[ROLE=([^\]]+)\] ]]; then
  ROLE="${BASH_REMATCH[1]}"
fi
if [[ "$RAW" =~ \[TASK_ID=([^\]]+)\] ]]; then
  TASK_ID="${BASH_REMATCH[1]}"
fi

if [[ -z "$ROLE" ]]; then
  ROLE="planner"
fi

TASK="$RAW"
TASK="${TASK//\[ROLE=${ROLE}\]/}"
if [[ -n "$TASK_ID" ]]; then
  TASK="${TASK//\[TASK_ID=${TASK_ID}\]/}"
  TASK="(TASK_ID=${TASK_ID}) ${TASK}"
fi
TASK="$(echo "$TASK" | sed 's/@[^ ]*//g' | xargs)"

"$(dirname "$0")/dispatch.sh" "$ROLE" "$TASK"
