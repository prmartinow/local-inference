#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

DATA_ROOT="${LOCAL_INFERENCE_DATA_ROOT:-${WEB_OSINT_DATA_ROOT:-data}}"
VENV="${LOCAL_INFERENCE_VENV:-${WEB_OSINT_QWEN_INFERENCE_VENV:-$DATA_ROOT/.venv-local-inference}}"
HOST="${LOCAL_INFERENCE_HOST:-127.0.0.1}"
PORT="${LOCAL_INFERENCE_PORT:-18200}"
LOG_LEVEL="${LOCAL_INFERENCE_LOG_LEVEL:-info}"

exec "$SCRIPT_DIR/run_with_cpu_thread_guard.sh" \
  "$VENV/bin/python" -m uvicorn local_inference.qwen_inference:app \
  --app-dir "$REPO_ROOT/src" \
  --host "$HOST" \
  --port "$PORT" \
  --log-level "$LOG_LEVEL"
