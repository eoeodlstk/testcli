#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ok() { echo "[OK] $1"; }
warn() { echo "[WARN] $1"; }
err() { echo "[ERR] $1"; }

command -v yq >/dev/null 2>&1 && ok "yq 설치됨" || err "yq 미설치 (brew install yq)"
command -v jq >/dev/null 2>&1 && ok "jq 설치됨" || err "jq 미설치 (brew install jq)"
command -v curl >/dev/null 2>&1 && ok "curl 설치됨" || err "curl 미설치"

[[ -f "$ROOT_DIR/roles.yaml" ]] && ok "roles.yaml 확인" || err "roles.yaml 없음"
[[ -x "$ROOT_DIR/scripts/dispatch.sh" ]] && ok "dispatch.sh 실행 가능" || err "dispatch.sh 실행권한 없음"
[[ -x "$ROOT_DIR/scripts/model_runner.sh" ]] && ok "model_runner.sh 실행 가능" || err "model_runner.sh 실행권한 없음"

echo

echo "[환경변수 점검]"
[[ -n "${OPENAI_API_KEY:-}" ]] && ok "OPENAI_API_KEY 설정" || warn "OPENAI_API_KEY 미설정 (co 사용 불가)"
[[ -n "${ANTHROPIC_API_KEY:-}" ]] && ok "ANTHROPIC_API_KEY 설정" || warn "ANTHROPIC_API_KEY 미설정 (op4/so 사용 불가)"
if [[ -n "${GEMINI_API_KEY:-}" || -n "${GOOGLE_API_KEY:-}" ]]; then
  ok "GEMINI_API_KEY/GOOGLE_API_KEY 설정"
else
  warn "GEMINI_API_KEY/GOOGLE_API_KEY 미설정 (gp 사용 불가)"
fi
if [[ -n "${ZHIPUAI_API_KEY:-}" || -n "${GLM_API_KEY:-}" ]]; then
  ok "ZHIPUAI_API_KEY/GLM_API_KEY 설정"
else
  warn "ZHIPUAI_API_KEY/GLM_API_KEY 미설정 (GLM 사용 불가)"
fi

echo

echo "[샘플 실행]"
echo "  ./scripts/dispatch.sh planner \"요구사항을 5개 작업으로 분해\""
echo "  ./scripts/dispatch.sh reviewer \"최종 품질 리뷰\""
