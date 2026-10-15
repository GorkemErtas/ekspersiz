"""Compare all Python test results with production master, never hiding regressions.

The baseline may contain known failures; each original test must retain its
outcome on this PR. Removed heap-trim-only tests are explicitly allowlisted;
any other missing test or new failure/error fails CI.
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
    expected_test_names = {name.split(" ", 1)[0] for name in allowed_missing}
    if expected_test_names != REMOVED_HEAP_TRIM_TESTS:
        raise SystemExit(f"Expected removed heap-only tests not all found: {expected_test_names}")
    print(f"Intentionally removed heap-only tests: {allowed_missing}")
    changed = [(name, outcome, current.get(name)) for name, outcome in baseline.items()
               if current.get(name) != outcome and name not in missing]
    new_bad = [(name, outcome) for name, outcome in current.items()
               if name not in baseline and outcome in ("FAIL", "ERROR")]
    if unexpected_missing or changed or new_bad:
        print(f"REGRESSIONS missing={unexpected_missing} changed={changed} new_bad={new_bad}")
        raise SystemExit(1)
    if current_exit != baseline_exit:
        raise SystemExit("Unexpected change in complete suite exit status")
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
