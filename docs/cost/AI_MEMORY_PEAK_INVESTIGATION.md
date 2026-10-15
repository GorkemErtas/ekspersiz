# AI memory peak investigation (2026-10-15)

## Real Railway observation

One successful damage analysis on the original deployment was followed by ~875 MB of steady RAM. A comparable successful analysis after PR #7 was followed by ~1.28 GB, with a similarly stable plateau after 20+ minutes. This is **not** evidence of a leak by itself. Analysis succeeded with apparently unchanged results; the measurements were not captured with identical instance lifetimes, traffic, or image metadata.

Railway environment inspection showed:

- `ekspersiz-ai`: Serverless **disabled**, so the process stays resident and continues accruing RAM usage even when CPU is idle.
- `ekspersiz-backend` and `Postgres`: Serverless enabled.
- Three YOLO weights stay resident after first image request, intentionally, for lower subsequent latency.

**Keep AI Serverless disabled for now**, because the first image request failed with the user's previous sleeping-service configuration.

## Low-risk, reversible change to test

- Set `OMP_NUM_THREADS=2`, `MKL_NUM_THREADS=2`, `OPENBLAS_NUM_THREADS=2`, and `AI_TORCH_NUM_THREADS=2` in the Python container defaults. Railway service variables can override these without code changes.
- `AI_TORCH_NUM_THREADS=0` disables the explicit `torch.set_num_threads` call (still honor OMP/MKL environment variables).
- Remove a redundant `PIL.Image.convert("RGB").copy()` copy. Color conversion, resolution and model inputs remain unchanged.

Model weights, YOLO thresholds, input quality thresholds, endpoints, response schemas, stored data and database are unchanged.

## Verification / decision

GitHub Actions runs two *separate Python processes on one runner* with four vs two CPU threads and identical synthetic input and model files. It reports each run's peak resident memory and cold-start latency; tests model detection equivalence. This is a controlled CPU-thread comparison **only**; it is not a before/after Railway bill or a real-image model-quality evaluation.

Before production merge, confirm CI passes and the two-thread variant does not have worse memory/latency on the CI hardware. If the result is inconclusive, don't deploy solely to reduce memory. Then compare at least three matched real-image analyses (same files) at similar load, record post-analysis RSS after 20 minutes, p95 response time and error rate. Revert immediately if first-image latency or results regress.

The user's previous ~one-month total Railway cost baseline was **$1.75**, with AI $0.5909, backend $0.9978 and Postgres $0.1602. Save future *GB-minute* and service-specific cost deltas, not only the instantaneous peak.
