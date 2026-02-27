#!/usr/bin/env bash
set -euo pipefail

# Unified runner for 5 fixed models
# default policy: non-GLM models run local CLI only (no paid API fallback)
# set ORCH_ALLOW_BILLED_API=1 to re-enable API fallback for non-GLM models
# models:
# - anthropic/claude-opus-4-6 (op4)
# - anthropic/claude-sonnet-4-6 (so)
# - openai-codex/gpt-5.3-codex (co)
# - google-gemini-cli/gemini-3-pro-preview (gp)
# - zai/glm-5 (GLM)

MODEL=""
PROMPT=""
PROMPT_FILE=""
TIMEOUT_SEC="${ORCH_TIMEOUT_SEC:-180}"
ALLOW_BILLED_API="${ORCH_ALLOW_BILLED_API:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="${2:-}"; shift 2 ;;
    --prompt) PROMPT="${2:-}"; shift 2 ;;
    --prompt-file) PROMPT_FILE="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT_SEC="${2:-180}"; shift 2 ;;
    *) echo "[ERR] unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$MODEL" ]] || { echo "[ERR] --model is required" >&2; exit 1; }

if [[ -n "$PROMPT_FILE" ]]; then
  [[ -f "$PROMPT_FILE" ]] || { echo "[ERR] prompt file not found: $PROMPT_FILE" >&2; exit 1; }
  PROMPT="$(cat "$PROMPT_FILE")"
fi
[[ -n "$PROMPT" ]] || { echo "[ERR] --prompt or --prompt-file is required" >&2; exit 1; }

# auto-load .env from project root if present
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env"
  set +a
fi

need_bin() { command -v "$1" >/dev/null 2>&1; }

no_billed_api_err() {
  local vendor="$1"
  echo "[ERR] ${vendor} API fallback is disabled by policy (ORCH_ALLOW_BILLED_API=0)." >&2
  echo "[HINT] Install/login ${vendor} CLI for local use, or set ORCH_ALLOW_BILLED_API=1 if you really want paid API fallback." >&2
  exit 1
}

extract_or_fail() {
  local raw="$1"
  local jq_expr="$2"

  local err
  err="$(printf '%s' "$raw" | jq -r '.error.message // .error // empty' 2>/dev/null || true)"
  if [[ -n "$err" && "$err" != "null" ]]; then
    echo "[ERR] API error: $err" >&2
    exit 1
  fi

  local out
  out="$(printf '%s' "$raw" | jq -r "$jq_expr" 2>/dev/null || true)"
  if [[ -z "$out" || "$out" == "null" ]]; then
    echo "[ERR] empty model output" >&2
    if [[ "${ORCH_DEBUG:-0}" == "1" ]]; then
      echo "[DEBUG] raw response: $raw" >&2
    fi
    exit 1
  fi

  printf '%s\n' "$out"
}

run_claude() {
  local model_name="$1"
  need_bin claude || return 1
  claude --print --output-format text --model "$model_name" -p "$PROMPT"
}

run_codex() {
  need_bin codex || return 1
  local msg_file
  msg_file="$(mktemp)"
  local err_file
  err_file="$(mktemp)"
  if ! codex exec --skip-git-repo-check --model "gpt-5.3-codex" -o "$msg_file" "$PROMPT" >/dev/null 2>"$err_file"; then
    cat "$err_file" >&2
    rm -f "$msg_file" "$err_file"
    return 1
  fi
  cat "$msg_file"
  rm -f "$msg_file" "$err_file"
}

run_gemini() {
  need_bin gemini || return 1
  gemini -p "$PROMPT" --model "gemini-3-pro-preview" --output-format text
}

openai_api() {
  need_bin curl && need_bin jq || { echo "[ERR] curl/jq 필요" >&2; exit 1; }
  local api_key="${OPENAI_API_KEY:-}"
  [[ -n "$api_key" ]] || { echo "[ERR] OPENAI_API_KEY is not set" >&2; exit 1; }

  local raw
  raw="$(curl -sS --max-time "$TIMEOUT_SEC" https://api.openai.com/v1/responses \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg model "gpt-5.3-codex" --arg input "$PROMPT" '{model:$model,input:$input}')")"
  extract_or_fail "$raw" '.output_text // (.output[]?.content[]?.text // empty)'
}

anthropic_api() {
  need_bin curl && need_bin jq || { echo "[ERR] curl/jq 필요" >&2; exit 1; }
  local model_name="$1"
  local api_key="${ANTHROPIC_API_KEY:-}"
  [[ -n "$api_key" ]] || { echo "[ERR] ANTHROPIC_API_KEY is not set" >&2; exit 1; }

  local raw
  raw="$(curl -sS --max-time "$TIMEOUT_SEC" https://api.anthropic.com/v1/messages \
    -H "x-api-key: ${api_key}" \
    -H "anthropic-version: 2023-06-01" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg model "$model_name" --arg prompt "$PROMPT" '{model:$model,max_tokens:2048,messages:[{role:"user",content:$prompt}]}')")"
  extract_or_fail "$raw" '.content[]? | select(.type=="text") | .text'
}

gemini_api() {
  need_bin curl && need_bin jq || { echo "[ERR] curl/jq 필요" >&2; exit 1; }
  local api_key="${GEMINI_API_KEY:-${GOOGLE_API_KEY:-}}"
  [[ -n "$api_key" ]] || { echo "[ERR] GEMINI_API_KEY (or GOOGLE_API_KEY) is not set" >&2; exit 1; }

  local endpoint="https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-preview:generateContent?key=${api_key}"
  local raw
  raw="$(curl -sS --max-time "$TIMEOUT_SEC" "$endpoint" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg prompt "$PROMPT" '{contents:[{parts:[{text:$prompt}]}]}')")"
  extract_or_fail "$raw" '.candidates[0].content.parts[0].text // empty'
}

glm_api() {
  need_bin curl && need_bin jq || { echo "[ERR] curl/jq 필요" >&2; exit 1; }
  local api_key="${ZHIPUAI_API_KEY:-${GLM_API_KEY:-}}"
  [[ -n "$api_key" ]] || { echo "[ERR] ZHIPUAI_API_KEY (or GLM_API_KEY) is not set" >&2; exit 1; }

  local raw
  raw="$(curl -sS --max-time "$TIMEOUT_SEC" https://open.bigmodel.cn/api/paas/v4/chat/completions \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg prompt "$PROMPT" '{model:"glm-5",messages:[{role:"user",content:$prompt}],temperature:0.2}')")"
  extract_or_fail "$raw" '.choices[0].message.content // empty'
}

case "$MODEL" in
  openai-codex/gpt-5.3-codex)
    if run_codex; then
      exit 0
    fi
    [[ "$ALLOW_BILLED_API" == "1" ]] || no_billed_api_err "OpenAI"
    openai_api ;;
  anthropic/claude-sonnet-4-6)
    if run_claude "claude-sonnet-4-6"; then
      exit 0
    fi
    [[ "$ALLOW_BILLED_API" == "1" ]] || no_billed_api_err "Anthropic"
    anthropic_api "claude-sonnet-4-6" ;;
  anthropic/claude-opus-4-6)
    if run_claude "claude-opus-4-6"; then
      exit 0
    fi
    [[ "$ALLOW_BILLED_API" == "1" ]] || no_billed_api_err "Anthropic"
    anthropic_api "claude-opus-4-6" ;;
  google-gemini-cli/gemini-3-pro-preview)
    if run_gemini; then
      exit 0
    fi
    [[ "$ALLOW_BILLED_API" == "1" ]] || no_billed_api_err "Gemini"
    gemini_api ;;
  zai/glm-5)
    glm_api ;;
  *)
    echo "[ERR] unsupported model: $MODEL" >&2
    exit 1 ;;
esac
