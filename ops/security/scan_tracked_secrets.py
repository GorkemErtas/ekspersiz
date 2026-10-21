"""Read-only, high-confidence scan of tracked text blobs, including reachable history.

Reports locations and rule names only. Never prints or writes matched secret values.
Not a substitute for provider-side secret scanning or credential rotation.
"""
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
RULES = {
    "private-key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "github-token": re.compile(rb"\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,})\b"),
    "aws-access-id": re.compile(rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "stripe-secret": re.compile(rb"\bsk_live_[A-Za-z0-9]{20,}\b"),
    "brevo-secret": re.compile(rb"\bxkeysib-[A-Za-z0-9-]{30,}\b"),
    "google-api-key-review-restrictions": re.compile(rb"\bAIza[A-Za-z0-9_-]{35}\b"),
}
EXTENSIONS = {".java", ".properties", ".json", ".yaml", ".yml", ".md", ".dart", ".py", ".txt",
              ".pem", ".key", ".env", ".xml", ".kts", ".sh", ".ts", ".ps1"}


def git(*args, **kwargs):
    return subprocess.check_output(["git", *args], cwd=ROOT, **kwargs)


if __name__ == "__main__":
    current = {}
    for line in git("ls-tree", "-r", "HEAD").decode().splitlines():
        meta, path = line.split("\t", 1)
        current[meta.split()[2]] = path
    candidates = {}
    for line in git("rev-list", "--objects", "--all").decode().splitlines():
        parts = line.split(" ", 1)
        if len(parts) == 2 and (Path(parts[1]).suffix.lower() in EXTENSIONS or ".env" in Path(parts[1]).name):
            candidates[parts[0]] = parts[1]
    sizes = git("cat-file", "--batch-check=%(objectname) %(objecttype) %(objectsize)",
                input=("\n".join(candidates) + "\n").encode()).decode().splitlines()
    findings = []
    scanned = 0
    for row in sizes:
        blob, kind, size = row.split()
        if kind != "blob" or int(size) > 2_000_000:
            continue
        data = git("cat-file", "blob", blob)
        if b"\x00" in data[:1000]:
            continue
        scanned += 1
        for rule, pattern in RULES.items():
            for match in pattern.finditer(data):
                findings.append({"rule": rule, "path": candidates[blob], "blob": blob,
                                 "line": data[:match.start()].count(b"\n") + 1,
                                 "in_head": blob in current})
    report = {"scope": "reachable git history, selected text types <=2MB, high-confidence patterns",
              "scanned_blobs": scanned, "findings": findings}
    (ROOT / "target/security-secret-scan.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
