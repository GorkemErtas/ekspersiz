"""Local before/after benchmark; never contacts Railway or changes model settings.

Run from ai-service with the same interpreter, images and machine for both revisions:
  python scripts/benchmark_single_photo_pipeline.py --output evaluation-runs/perf-before.json
  python scripts/benchmark_single_photo_pipeline.py --output evaluation-runs/perf-after.json
Real inference uses the existing test-images/*.jpg only when --real-images is supplied.
"""
import argparse
import hashlib
import json
from pathlib import Path
import statistics
import subprocess
import sys
import time
import tracemalloc


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def quality_worker():
    import cv2
    import numpy as np
    import psutil
    from PIL import Image
    from app.damage_analyzer import DamageAnalyzer

    cv2.setNumThreads(1)  # Benchmark only, identical in both revisions.
    analyzer = DamageAnalyzer.__new__(DamageAnalyzer)
    analyzer.minimum_brightness = 35.0
    analyzer.minimum_blur_score = 20.0
    pixels = np.random.default_rng(2026).integers(0, 256, (3024, 4032, 3), dtype=np.uint8)
    image = Image.fromarray(pixels)
    del pixels
    analyzer._photometric_quality_issue(Image.new("RGB", (32, 32), "white"))
    tracemalloc.start()
    started, cpu_started = time.perf_counter(), time.process_time()
    result = analyzer._photometric_quality_issue(image)
    elapsed, cpu = time.perf_counter() - started, time.process_time() - cpu_started
    _, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    memory = psutil.Process().memory_info()
    if hasattr(memory, "peak_wset"):
        peak_rss = memory.peak_wset
    else:
        import resource
        peak_rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        if sys.platform != "darwin":
            peak_rss *= 1024
    return {"seconds": elapsed, "cpu_seconds": cpu,
            "peak_traced_mib": peak / 1024**2, "process_peak_rss_mib": peak_rss / 1024**2,
            "quality": None if result is None else result.model_dump(mode="json")}


def real_images():
    import torch
    from app.damage_analyzer import DamageAnalyzer
    torch.set_num_threads(2)  # Benchmark only; production thread counts are untouched.
    started = time.perf_counter()
    analyzer = DamageAnalyzer()
    output = {"model_init_seconds": time.perf_counter() - started, "samples": [], "weights": {}}
    for path in (analyzer.vehicle_model_path, analyzer.damage_model_path, analyzer.vehicle_part_model_path):
        output["weights"][str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    for path in sorted((ROOT / "test-images").glob("*.jpg")):
        content = path.read_bytes()
        for region in (None, "FRONT", "REAR"):
            started, cpu_started = time.perf_counter(), time.process_time()
            result = analyzer.analyze(content, path.name, region)
            output["samples"].append({
                "filename": path.name, "sha256": hashlib.sha256(content).hexdigest(), "region": region,
                "seconds": time.perf_counter() - started, "cpu_seconds": time.process_time() - cpu_started,
                "result": result.model_dump(mode="json"),
            })
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--real-images", action="store_true")
    parser.add_argument("--compare", type=Path, help="Compare --output with a previous saved report; no inference")
    parser.add_argument("--quality-worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.quality_worker:
        print("BENCHMARK_RESULT=" + json.dumps(quality_worker()))
        return
    if args.output is None or args.repeats < 1:
        parser.error("--output and a positive --repeats are required")
    if args.compare is not None:
        before = json.loads(args.compare.read_text(encoding="utf-8"))
        after = json.loads(args.output.read_text(encoding="utf-8"))
        assert before["real_images"]["weights"] == after["real_images"]["weights"]
        pairs = list(zip(before["real_images"]["samples"], after["real_images"]["samples"], strict=True))
        assert all(all(a[key] == b[key] for key in ("filename", "sha256", "region", "result")) for a, b in pairs)
        print(json.dumps({"identical_complete_results": len(pairs),
                          "before": before["quality_medians"], "after": after["quality_medians"],
                          "inference_median_seconds": [statistics.median(a["seconds"] for a, _ in pairs),
                                                       statistics.median(b["seconds"] for _, b in pairs)]}))
        return
    runs = []
    for _ in range(args.repeats):
        worker = subprocess.run([sys.executable, str(Path(__file__).resolve()), "--quality-worker"],
                                cwd=ROOT, capture_output=True, text=True, check=True)
        line = next(line for line in worker.stdout.splitlines() if line.startswith("BENCHMARK_RESULT="))
        runs.append(json.loads(line.split("=", 1)[1]))
    report = {"python": sys.version, "platform": sys.platform, "quality_dimensions": [4032, 3024],
              "quality_runs": runs, "quality_medians": {
                  metric: statistics.median(run[metric] for run in runs)
                  for metric in ("seconds", "cpu_seconds", "peak_traced_mib", "process_peak_rss_mib")}}
    if args.real_images:
        report["real_images"] = real_images()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({"output": str(args.output), "quality_medians": report["quality_medians"]}))


if __name__ == "__main__":
    main()
