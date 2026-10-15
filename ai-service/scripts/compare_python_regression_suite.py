"""Compare all Python test results with production master, never hiding regressions.

The baseline may contain known failures; each original test must retain its
outcome on this PR. Any new failure/error or missing baseline test fails CI.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

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
    changed = [(name, outcome, current.get(name)) for name, outcome in baseline.items()
               if current.get(name) != outcome and name not in missing]
    new_bad = [(name, outcome) for name, outcome in current.items()
               if name not in baseline and outcome in ("FAIL", "ERROR")]
    if missing or changed or new_bad:
        print(f"REGRESSIONS missing={missing} changed={changed} new_bad={new_bad}")
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
