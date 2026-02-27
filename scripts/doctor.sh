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

echo "[실행 경로 점검]"
command -v codex >/dev/null 2>&1 && ok "codex CLI 설치됨 (co)" || warn "codex CLI 미설치 (co 실행 불가, API fallback은 기본 비활성)"
command -v claude >/dev/null 2>&1 && ok "claude CLI 설치됨 (op4/so)" || warn "claude CLI 미설치 (op4/so 실행 불가, API fallback은 기본 비활성)"
command -v gemini >/dev/null 2>&1 && ok "gemini CLI 설치됨 (gp)" || warn "gemini CLI 미설치 (gp 실행 불가, API fallback은 기본 비활성)"

if [[ -n "${ZHIPUAI_API_KEY:-}" || -n "${GLM_API_KEY:-}" ]]; then
  ok "ZHIPUAI_API_KEY/GLM_API_KEY 설정 (GLM)"
else
  warn "ZHIPUAI_API_KEY/GLM_API_KEY 미설정 (GLM 사용 불가)"
fi

if [[ "${ORCH_ALLOW_BILLED_API:-0}" == "1" ]]; then
  warn "ORCH_ALLOW_BILLED_API=1 (유료 API fallback 활성화)"
else
  ok "ORCH_ALLOW_BILLED_API=0 (기본값, 비-GLM 유료 API fallback 비활성)"
fi

echo

echo "[샘플 실행]"
echo "  ./scripts/dispatch.sh planner \"요구사항을 5개 작업으로 분해\""
echo "  ./scripts/dispatch.sh reviewer \"최종 품질 리뷰\""
