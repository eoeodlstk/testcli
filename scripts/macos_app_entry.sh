#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DISPATCH="$ROOT_DIR/scripts/dispatch.sh"
DOCTOR="$ROOT_DIR/scripts/doctor.sh"

if [[ ! -x "$DISPATCH" ]]; then
  osascript -e 'display alert "orchestration-cli 오류" message "dispatch.sh를 찾을 수 없어요." as critical'
  exit 1
fi

ROLE="$(osascript <<'APPLESCRIPT'
text returned of (display dialog "역할을 입력하세요 (planner/coder/researcher/operator/reviewer)" default answer "planner" buttons {"취소", "확인"} default button "확인")
APPLESCRIPT
)"

TASK="$(osascript <<'APPLESCRIPT'
text returned of (display dialog "작업 지시를 입력하세요" default answer "요구사항을 5개 작업으로 분해" buttons {"취소", "실행"} default button "실행")
APPLESCRIPT
)"

if [[ -z "${ROLE// }" || -z "${TASK// }" ]]; then
  osascript -e 'display notification "역할/작업 입력이 비어 있어 실행을 중단했습니다." with title "orchestration-cli"'
  exit 1
fi

# Run in Terminal so user can observe progress/logs.
osascript <<APPLESCRIPT
set cmd to "cd " & quoted form of "$ROOT_DIR" & " && ./scripts/doctor.sh; echo; ./scripts/dispatch.sh " & quoted form of "$ROLE" & " " & quoted form of "$TASK" & "; echo; echo '완료: runs 폴더를 확인하세요.'; read -n 1 -s -r -p '아무 키나 누르면 종료됩니다...'"
tell application "Terminal"
  activate
  do script cmd
end tell
APPLESCRIPT
