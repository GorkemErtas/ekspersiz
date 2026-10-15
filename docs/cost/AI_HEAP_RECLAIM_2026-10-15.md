# Opt-in native heap reclamation after AI requests

## Why

Railway user measurements on 2026-10-15: AI sustained ~875 MB after an image request in the old deployment, and ~1.28 GB after an image request in the current deployment; both plateaus persisted for over 20 minutes. App Sleeping / Serverless on AI is intentionally kept **disabled** because users observed failed first analyses.

Current AI holds all three YOLO model objects in memory after first use for warm inference. An additional part of resident RAM may be freed native/Python allocator pages from decoded large photos and tensor intermediates.

## Evidence

A controlled GitHub Actions experiment with actual committed YOLO models and 3072x2304 synthetic JPEG validation found that after garbage collection alone, memory remained roughly unchanged, but calling Linux glibc `malloc_trim(0)` once afterward reduced RSS:

- 3-thread run: ~610.3 MiB to ~469.6 MiB (141 MiB)
- 2-thread run: ~553.1 MiB to ~471.9 MiB (81 MiB)

The experiment does **not** prove that Railway will have the same savings. Thread-count reduction showed no repeatable peak reduction in our two runs, so it is **not** included in this PR.

## Proposed approach

- `AI_TRIM_HEAP_AFTER_INFERENCE=false` by default (change with Railway service environment variable to enable after deployment).
- When true and running on glibc Linux, call `malloc_trim(0)` once after each image validation or analysis while inference concurrency remains serialized. This asks glibc to return **unused** pages to the OS; it does not unload live YOLO models and does not force Python garbage collection.
- Remove redundant `.copy()` immediately after converting the uploaded Pillow image to RGB; `.convert("RGB")` already owns a distinct pixel buffer, so detection pixels do not change.
- No change to class labels, weights, thresholds, image resolution, API schema, or storage.

## Release checklist

- Run two **separate processes on the same GitHub runner** (flag off vs on) using the same models and large synthetic images; record peak and post-analysis RSS and first-request time. Detectable improvement must be observed before enabling this in production.
- Compare with a sample of genuine vehicle damage images in staging or live only with permission; inspect classification, output, latency, 5xx rate, and CPU usage.
- Do not enable AI Serverless. If performance regresses or gains are inconsistent, leave `AI_TRIM_HEAP_AFTER_INFERENCE=false` (default).
- After a controlled production test, compare Railway RAM GB-min and HTTP latency over equal length and comparable traffic windows.

**Baseline:** project was about $1.75 for ~one month (backend $0.9978, AI $0.5909, PostgreSQL $0.1602). No production savings claimed.


## Robustness verification

The single-pair CI benchmark was promising but could have been distorted by allocation variability. A follow-up workflow tests **three fresh Python processes per condition**, with 12 large-image validations per process. It checks model/quality equivalence, logs retained RSS at the end of each batch of four, and reports median retained RSS and validation latency. This is a synthetic CPU-runner test, not a production SLO; repeat with real-world photos and Railway RAM GB-min before claiming monthly savings.

The trim call is also guarded: if the optional native operation raises an exception, it logs a warning and does **not** turn a successful analysis into HTTP 500. Production still defaults to `AI_TRIM_HEAP_AFTER_INFERENCE=false`.


## Full-suite legacy test issues (not introduced by this PR)

The first attempt to run **all 95 Python unit tests** reported 2 assertions failing in `test_assistant_domain_classifier` (expected error strings disagree with the router's actual invalid-boolean error), plus one `test_experiment_tools` error because `datasets/vehicle_damage_detection_v2/images/train/cardd` is absent from the checkout. These failures are unrelated to memory trimming, but their baseline status must be confirmed before merging. The CI now runs the same suite against both untouched `master` and this PR, failing if any baseline test changes outcome or any new test fails. **This check does not claim the full suite passes.** The underlying legacy failures should be fixed separately after investigation.
