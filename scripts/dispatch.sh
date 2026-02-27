#!/usr/bin/env bash
set -euo pipefail

# usage:
#   ./scripts/dispatch.sh planner "새 기능 아키텍처 제안해줘"
# env:
#   ORCH_RUNNER: 실행기 선택 (default: ./scripts/model_runner.sh)
#   ORCH_OUT_DIR: 출력 디렉토리 (default: ./runs)

ROLE="${1:-}"
shift || true
TASK="${*:-}"

if [[ -z "$ROLE" || -z "$TASK" ]]; then
  echo "[ERR] usage: $0 <role> <task>"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROLES_FILE="$ROOT_DIR/roles.yaml"
OUT_DIR="${ORCH_OUT_DIR:-$ROOT_DIR/runs}"
RUNNER="${ORCH_RUNNER:-$ROOT_DIR/scripts/model_runner.sh}"
TS="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR"

if ! command -v yq >/dev/null 2>&1; then
  echo "[ERR] yq가 필요합니다. (brew install yq)"
  exit 1
fi

MODEL_ALIAS="$(yq -r ".roles.${ROLE}.model_alias // \"\"" "$ROLES_FILE")"
PROVIDER_MODEL="$(yq -r ".roles.${ROLE}.provider_model // \"\"" "$ROLES_FILE")"
PURPOSE="$(yq -r ".roles.${ROLE}.purpose // \"\"" "$ROLES_FILE")"

if [[ -z "$MODEL_ALIAS" || -z "$PROVIDER_MODEL" ]]; then
  echo "[ERR] unknown role: $ROLE"
  exit 1
fi

PROMPT=$(printf '%s\n' \
  "[ROLE=${ROLE}]" \
  "[MODEL_ALIAS=${MODEL_ALIAS}]" \
  "[MODEL=${PROVIDER_MODEL}]" \
  "[PURPOSE=${PURPOSE}]" \
  "" \
  "지시사항:" \
  "- 한국어로, 정중하고 간결하게 답변" \
  "- 출력 형식: 1) 요약 2) 실행 항목 3) 리스크/확인사항" \
  "" \
  "작업:" \
  "${TASK}")

OUT_FILE="$OUT_DIR/${TS}-${ROLE}.md"

if [[ "$RUNNER" == "echo" ]]; then
  {
    echo "# Dispatch Preview"
    echo
    echo "- role: $ROLE"
    echo "- alias: $MODEL_ALIAS"
    echo "- model: $PROVIDER_MODEL"
    echo
    echo '```'
    echo "$PROMPT"
    echo '```'
  } > "$OUT_FILE"
  echo "[OK] preview 생성: $OUT_FILE"
  exit 0
fi

PROMPT_FILE="$(mktemp)"
printf "%s" "$PROMPT" > "$PROMPT_FILE"

# RUNNER 인터페이스:
#   $RUNNER --model <provider_model> --prompt-file <file>
if "$RUNNER" --model "$PROVIDER_MODEL" --prompt-file "$PROMPT_FILE" > "$OUT_FILE"; then
  rm -f "$PROMPT_FILE"
  echo "[OK] run 완료: $OUT_FILE"
  exit 0
fi

# 기본 모델 실패 시 codex(co)로 1회 자동 폴백
if [[ "$PROVIDER_MODEL" != "openai-codex/gpt-5.3-codex" ]]; then
  {
    echo "[fallback] primary model 실패로 co(openai-codex/gpt-5.3-codex)로 재시도"
    echo
  } > "$OUT_FILE"
  "$RUNNER" --model "openai-codex/gpt-5.3-codex" --prompt-file "$PROMPT_FILE" >> "$OUT_FILE"
  rm -f "$PROMPT_FILE"
  echo "[OK] fallback run 완료: $OUT_FILE"
  exit 0
fi

rm -f "$PROMPT_FILE"
exit 1
