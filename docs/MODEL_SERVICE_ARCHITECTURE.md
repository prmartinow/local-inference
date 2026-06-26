# Model Service Architecture

## Direction

Model execution belongs in a shared local model-serving layer. Application services and batch jobs call that layer through an API; they do not own model weights, loading, concurrency, CPU thread policy, or retry policy.

## Service Boundary

```text
model runtime services
  load model weights
  run inference
  expose health, metrics, active/waiting state, and model inventory

local-inference API
  stable HTTP surface for embedding, rerank, VL, OCR, and helper routes
  owns per-operation guardrails and observability

client services
  repo-analysis
  Web OSINT embedding/search workers
  dashboards and research search coordinators
  media enrichment workers
  batch backfills and evaluations
```

## Current Shape

The first `local-inference` version is a single FastAPI process with lazy loading for:

- Qwen text embeddings.
- Qwen reranker.
- Qwen VL embedding.
- Qwen VL generative chat.
- Small specialized helper models for CAPTCHA/OCR routes.

This keeps the current working behavior easy to operate while establishing the correct ownership boundary. Split heavyweight model families into separate runtime processes only when memory, fault isolation, scheduling, or deployment pressure justifies it.

## Operational Rules

- Slow transformer lanes have no queue timeout: text embedding, query embedding, batch embedding, rerank, VL embedding, and VL chat.
- Queue limits and concurrency limits are backpressure.
- `/healthz` exposes guardrail state so operators can see whether work is active, waiting, idle, or blocked.
- `/metrics` exposes counters and durations by operation, model, and caller.
- Clients should not retry a slow model request while the model may still be working on it.
- Host-specific paths, tokens, and model caches live in env files or ignored data directories, not in Git.
- Downloader scripts, Hugging Face cache setup, model-root paths, and
  candidate/evaluation model manifests live here rather than in client repos.

## Migration Notes

The code was extracted from the Web OSINT Qwen inference service. During migration, the API accepts selected older `WEB_OSINT_*` environment names as fallbacks, but new deployments should use `LOCAL_INFERENCE_*` and the `local-inference.service` unit names.
