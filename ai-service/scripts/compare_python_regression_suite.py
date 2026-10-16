"""Compare the Python suite with the branch baseline, identifying new regressions.

Pre-existing failures remain visible. Improvements (e.g. fixing a failing test)
are permitted; unexpected dropped tests and newly failed tests are rejected.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

# These five tests exclusively exercised the opt-in native heap feature that
# was never enabled in production and is intentionally removed in this PR.
REMOVED_HEAP_TRIM_TESTS = frozenset({
    "test_heap_reclamation_is_opt_in",
    "test_heap_reclamation_only_calls_native_trim_when_enabled",
    "test_heap_reclaim_failure_must_not_fail_analysis",
    "test_inference_exception_survives_heap_cleanup",
    "test_run_operation_releases_native_heap_after_return",
})

RESULT_PATTERN = re.compile(
    r"^(test_\w+ \([^\n]+\)) \.\.\. (ok|FAIL|ERROR|skipped .+)$",
    re.MULTILINE,
)


def test_results(root: Path, label: str) -> tuple[dict[str, str], int]:
    env = os.environ.copy()
    env["PYTHONPATH"] = str(root / "ai-service")
    command = [sys.executable, "-m", "unittest", "discover", "-s",
               "ai-service/tests", "-p", "test_*.py", "-v"]
    completed = subprocess.run(command, cwd=root, env=env,
                               text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, timeout=300,
                               check=False)
    logfile = Path("/tmp") / f"ekspersiz-{label}-python-tests.log"
    logfile.write_text(completed.stdout, encoding="utf-8")
    results = dict(RESULT_PATTERN.findall(completed.stdout))
    print(f"{label}: {len(results)} named tests; exit {completed.returncode}; "
          f"failures={[(k, v) for k, v in results.items() if v in ('FAIL', 'ERROR')]}",
          flush=True)
    print(f"{label}: full log saved to {logfile}", flush=True)
    if not results or not re.search(r"Ran \d+ tests?", completed.stdout):
        print(completed.stdout[-8000:])
        raise RuntimeError(f"{label}: did not produce a complete unittest report")
    failures_reported = any(x in completed.stdout for x in ("FAILED (", "ERROR: ", "FAIL: "))
    if (completed.returncode != 0) != failures_reported:
        raise RuntimeError(f"{label}: inconsistent test runner exit; see {logfile}")
    return results, completed.returncode


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline-root", type=Path, required=True)
    args = parser.parse_args()
    baseline_root = args.baseline_root.resolve()
    current_root = Path(__file__).resolve().parents[2]
    baseline, baseline_exit = test_results(baseline_root, "master")
    current, current_exit = test_results(current_root, "pr")

    missing = sorted(set(baseline) - set(current))
    allowed_missing = sorted(name for name in missing
                             if name.split(" ", 1)[0] in REMOVED_HEAP_TRIM_TESTS)
    unexpected_missing = sorted(set(missing) - set(allowed_missing))
    if allowed_missing:
        print(f"Intentionally removed heap-only tests: {allowed_missing}")
    bad = {"FAIL", "ERROR"}
    newly_failed = [(name, prior, current[name])
                    for name, prior in baseline.items()
                    if name in current and current[name] in bad and prior not in bad]
    new_bad = [(name, outcome) for name, outcome in current.items()
               if name not in baseline and outcome in bad]
    if unexpected_missing or newly_failed or new_bad:
        print(f"REGRESSIONS missing={unexpected_missing} newly_failed={newly_failed} new_bad={new_bad}")
        # Surface new failure tracebacks directly in CI logs for fast diagnosis.
        # Historical baseline failures are not treated as regressions.
        current_log = Path("/tmp/ekspersiz-pr-python-tests.log")
        if current_log.exists():
            print("=== PR unittest failure details ===", flush=True)
            for line in current_log.read_text(encoding="utf-8").splitlines()[-180:]:
                print(line, flush=True)
        raise SystemExit(1)
    if current_exit != baseline_exit and current_exit != 0:
        raise SystemExit("Full suite exit status worsened unexpectedly")
    existing = [(name, outcome) for name, outcome in baseline.items()
                if outcome in ("FAIL", "ERROR")]
    print(f"NO NEW REGRESSIONS: {len(baseline)} baseline tests; "
          f"{len(current)} PR tests; {len(existing)} pre-existing failures/errors.")
    if existing:
        print("WARNING: full suite still has pre-existing failures/errors; "
              "the baseline comparison only verifies no new regressions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
