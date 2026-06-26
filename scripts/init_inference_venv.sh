#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

DATA_ROOT="${LOCAL_INFERENCE_DATA_ROOT:-${WEB_OSINT_DATA_ROOT:-data}}"
VENV="${LOCAL_INFERENCE_VENV:-${WEB_OSINT_QWEN_INFERENCE_VENV:-$DATA_ROOT/.venv-local-inference}}"
REQUIREMENTS_FILE="${LOCAL_INFERENCE_REQUIREMENTS:-$REPO_ROOT/requirements.txt}"
PADDLEOCR_HOME="${LOCAL_INFERENCE_PADDLEOCR_HOME:-${PADDLEOCR_HOME:-$DATA_ROOT/paddleocr}}"
PADDLEX_CACHE_HOME="${LOCAL_INFERENCE_PADDLE_PDX_CACHE_HOME:-${PADDLE_PDX_CACHE_HOME:-$PADDLEOCR_HOME/paddlex-cache}}"

mkdir -p "$DATA_ROOT" "$PADDLEOCR_HOME" "$PADDLEX_CACHE_HOME"
export PADDLEOCR_HOME
export PADDLE_PDX_CACHE_HOME="$PADDLEX_CACHE_HOME"
export PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT="${PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT:-0}"

if [[ ! -x "$VENV/bin/python" ]]; then
  echo "[$(date -Is)] creating local inference venv: $VENV"
  python3 -m venv "$VENV"
fi

echo "[$(date -Is)] upgrading pip"
"$VENV/bin/python" -m pip install -U pip setuptools wheel

echo "[$(date -Is)] installing CPU PyTorch runtime on data disk"
"$VENV/bin/python" -m pip install \
  --index-url https://download.pytorch.org/whl/cpu \
  "torch==2.8.0" "torchvision==0.23.0"

echo "[$(date -Is)] installing local inference dependencies from $REQUIREMENTS_FILE"
"$VENV/bin/python" -m pip install -r "$REQUIREMENTS_FILE"

echo "[$(date -Is)] local inference venv ready"
"$VENV/bin/python" - <<'PY'
import importlib.metadata as md

for package in ["torch", "transformers", "sentence-transformers", "fastapi", "uvicorn", "paddlepaddle", "paddlex", "paddleocr"]:
    print(f"{package}={md.version(package)}")
PY
