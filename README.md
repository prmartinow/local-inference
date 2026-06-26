# local-inference

Standalone local model-serving service for CPU-hosted Qwen inference on an RPC-style node.

The repo contains the model API code extracted from the Web OSINT local Qwen service and repackaged as a generic `local-inference` service. It does not include model weights, Hugging Face caches, logs, browser/session state, captured data, or secrets.

## What It Serves

- Text embeddings: `Qwen/Qwen3-Embedding-8B`
- Reranking: `Qwen/Qwen3-Reranker-8B`
- VL embeddings: `Qwen/Qwen3-VL-Embedding-8B`
- Generative VL chat: `Qwen/Qwen3-VL-8B-Instruct`
- Small helper routes: reCAPTCHA tile classification, ddddocr text OCR, and slider-gap matching

## API

Default bind: `127.0.0.1:18200`

```text
GET  /healthz
GET  /metrics
POST /warmup
POST /embed
POST /v1/embeddings
POST /rerank
POST /v1/chat/completions
POST /classify_recaptcha
POST /ocr
POST /slide_gap
```

Slow transformer lanes intentionally have no queue timeout: text embedding, batch embedding, query embedding, rerank, VL embedding, and VL chat. Use `/healthz` guardrail state and `/metrics` counters/durations to tell whether work is active, queued, idle, or failing.

## Install

```bash
mkdir -p ~/.config/systemd/user ~/.config/local-inference
cp systemd/user/local-inference*.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now local-inference.service
```

For large model storage, create a local override:

```bash
mkdir -p ~/.config/systemd/user/local-inference.service.d
cp systemd/user/local-inference.service.d/rpc-node.example.conf \
  ~/.config/systemd/user/local-inference.service.d/rpc-node.conf
systemctl --user daemon-reload
systemctl --user restart local-inference.service
```

## Model Downloads

```bash
cp systemd/user/local-inference-model-downloads.service ~/.config/systemd/user/
cp systemd/user/local-inference-model-download-progress.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now local-inference-model-downloads.service
systemctl --user enable --now local-inference-model-download-progress.service
```

Auth, if needed, must be supplied through `HF_TOKEN`, `HF_TOKEN_FILE`, or `LOCAL_INFERENCE_HF_TOKEN_FILE` in a local environment file. Do not commit that file.

## Development Checks

```bash
python3 -m py_compile src/local_inference/qwen_inference.py
bash -n scripts/*.sh
```
