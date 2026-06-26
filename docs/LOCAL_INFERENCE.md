# Local Inference

`local-inference` is a shared local model API for CPU-hosted inference on an RPC-style node. It is intentionally separate from application services such as repo-analysis, Web OSINT workers, dashboards, and batch jobs.

## Model Set

| Role | Default model | Default directory |
| --- | --- | --- |
| Text embeddings | `Qwen/Qwen3-Embedding-8B` | `models/Qwen3-Embedding-8B` |
| Reranking | `Qwen/Qwen3-Reranker-8B` | `models/Qwen3-Reranker-8B` |
| VL embeddings | `Qwen/Qwen3-VL-Embedding-8B` | `models/Qwen3-VL-Embedding-8B` |
| Generative VL chat | `Qwen/Qwen3-VL-8B-Instruct` | `models/Qwen3-VL-8B-Instruct` |
| reCAPTCHA tile classifier | `DannyLuna/recaptcha-classification-57k` | `models/recaptcha-yolov8n/recaptcha_classification_57k.onnx` |
| OCR / slider gap | `ddddocr` bundled ONNX | Python wheel cache |
| Media/document OCR | PaddleOCR 3.7 / PaddleX 3.7 / PaddlePaddle 3.3 | `paddleocr/` cache under `LOCAL_INFERENCE_DATA_ROOT` |

The service reads model paths from `QWEN_*_MODEL_DIR` environment variables. `LOCAL_INFERENCE_DATA_ROOT` defaults to `data` when running directly from the repo; the systemd unit defaults to `%h/.local/share/local-inference`.

For RPC deployments, use `/mnt/data/local-inference` as the target data root and
`/mnt/data/local-inference/models` as the target model root. During migration,
the older live Web OSINT service may still report model paths under
`/mnt/data/web-osint-platform/models`; treat `/healthz` as authoritative before
moving, deleting, or assuming a model root. `ddddocr` is intentionally listed as
Python wheel cache because it does not use a separate model directory.

The helper model lanes have their own runtime dependencies in the service venv:
`ultralytics`, `onnxruntime`, and `opencv-python-headless` for the YOLOv8n
reCAPTCHA classifier, plus `ddddocr` for OCR and slide matching. The
filesystem-backed helper artifact is the reCAPTCHA ONNX file; ddddocr's ONNX
models are bundled in the wheel and become visible only through loaded-model
state and route behavior, not as `model_path_exists` entries.

PaddleOCR is model-serving runtime too. Local inference owns the PaddleOCR,
PaddleX, and PaddlePaddle install, model/cache directories, CPU policy, startup
self-test, and `/media/ocr` route. Web OSINT media workers call this route and
must not install or load PaddleOCR themselves.

## API

Default bind: `127.0.0.1:18200`.

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
POST /media/ocr
POST /slide_gap
```

`/healthz` reports model paths, loaded-model inventory, CPU thread guard state, and per-operation guardrails. `/metrics` exposes Prometheus-format request, duration, queue-wait, and guardrail gauges with `local_inference_*` metric names.

## Slow-Model Contract

Slow transformer lanes do not timeout while queued:

| Operation | Default policy |
| --- | --- |
| Offline/chunk embedding | concurrency `1`, queue `64`, no queue timeout |
| Batch embedding | concurrency `1`, queue `1`, no queue timeout |
| Query embedding | concurrency `1`, queue `4`, no queue timeout |
| Rerank | concurrency `1`, queue `2`, no queue timeout, max `5` candidates |
| VL embedding | concurrency `1`, queue `16`, no queue timeout |
| Generative VL chat | concurrency `1`, queue `4`, no queue timeout |

Clients should not add retries or HTTP timeouts for these slow lanes while a request may still be active. Use `/healthz` `active` / `waiting` and `/metrics` counters/durations to decide whether work is moving, queued, idle, or failing.

Small helper lanes remain timeout-bounded because they are expected to be fast:

```text
reCAPTCHA classifier: concurrency 2, queue 8, timeout 60s
OCR:                  concurrency 2, queue 8, timeout 60s
Media OCR:            concurrency 1, queue 8, no queue timeout
slide gap:            concurrency 2, queue 8, timeout 60s
```

The Web OSINT Part A2 route smoke checked synthetic fixtures only:
`/classify_recaptcha` synthetic traffic-light classification at 90.6% in about
302 ms, `/ocr` in about 20 ms, and `/slide_gap` correct offset in about 81 ms.
Do not treat these numbers as production SLAs or as broad CAPTCHA benchmark
coverage.

## Install

```bash
mkdir -p ~/.config/systemd/user ~/.config/local-inference
cp systemd/user/local-inference*.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now local-inference.service
```

Use a drop-in or `~/.config/local-inference/local-inference.env` for host-specific paths. Keep secrets out of the repo.

## Download Models

```bash
systemctl --user enable --now local-inference-model-downloads.service
systemctl --user enable --now local-inference-model-download-progress.service
tail -F ~/.local/share/local-inference/logs/model-downloads/latest-progress.log
```

The progress log reports service state, elapsed time, active model, transfer rates, socket count, per-model directory sizes, and active `.incomplete` file sizes. Hugging Face auth is optional for public models and must come from `HF_TOKEN`, `HF_TOKEN_FILE`, or `LOCAL_INFERENCE_HF_TOKEN_FILE`.

## Candidate Model Downloads

Application repos should not own model download scripts or manifests. Candidate
and evaluation model downloads are managed by local-inference as separate
optional units:

```bash
systemctl --user enable --now local-inference-candidate-model-downloads.service
systemctl --user enable --now local-inference-candidate-model-download-progress.service
tail -F ~/.local/share/local-inference/logs/candidate-model-downloads/latest-progress.log
```

The default manifest is `config/candidate-models.tsv`, and the default target is
`models/candidates` under `LOCAL_INFERENCE_DATA_ROOT`. Use
`LOCAL_INFERENCE_CANDIDATE_MODEL_MANIFEST`,
`LOCAL_INFERENCE_CANDIDATE_MODELS_DIR`, and
`LOCAL_INFERENCE_CANDIDATE_DOWNLOAD_JOBS` for host-specific overrides.

## Checks

```bash
curl -fsS http://127.0.0.1:18200/healthz | python3 -m json.tool
curl -fsS http://127.0.0.1:18200/metrics
python3 -m py_compile src/local_inference/qwen_inference.py
bash -n scripts/*.sh
```
