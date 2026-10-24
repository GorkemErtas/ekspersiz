"""Query OSV using only package names/versions; never uploads source or credentials.

First: ./mvnw dependency:list -DincludeScope=runtime -DoutputFile=target/security-java-dependencies.txt
Then: python ops/security/audit_dependencies.py
The report includes exact query coverage; absence of advisories is not a security guarantee.
"""
import concurrent.futures
import argparse
import json
from pathlib import Path
import re
import urllib.request
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]


def packages():
    found = set()
    for line in (ROOT / "target/security-java-dependencies.txt").read_text(encoding="utf-8").splitlines():
        parts = line.strip().split(" ")[0].split(":")
        # Classifier-bearing native artifacts have one extra coordinate.
        if len(parts) in (5, 6) and parts[-1] in ("compile", "runtime"):
            found.add(("Maven", f"{parts[0]}:{parts[1]}", parts[-2]))
    for filename in ("requirements.txt", "requirements-runtime.txt", "requirements-training.txt", "requirements-transfer.txt"):
        content = (ROOT / "ai-service" / filename).read_bytes()
        encoding = "utf-16" if content.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig"
        for line in content.decode(encoding).splitlines():
            match = re.match(r"([\w.-]+)(?:\[[^]]+\])?==([^\s;]+)", line)
            if match:
                found.add(("PyPI", match[1], match[2]))
    lock = (ROOT / "mobile/pubspec.lock").read_text(encoding="utf-8")
    for name, block in re.findall(r"^  ([\w_]+):\n(.*?)(?=^  \w+:|^sdks:)", lock, re.M | re.S):
        version = re.search(r'^    version: "([^"]+)"', block, re.M)
        if version and "source: hosted" in block:
            found.add(("Pub", name, version[1]))
    resolved = ROOT / "target/security-python-resolved.json"
    if resolved.exists():
        raw = resolved.read_bytes()
        for package in json.loads(raw.decode("utf-16" if raw.startswith(b"\xff\xfe") else "utf-8-sig")):
            found.add(("PyPI", package["name"], package["version"]))
    return sorted(found)


def fetch(package):
    ecosystem, name, version = package
    payload = {"package": {"ecosystem": ecosystem, "name": name}, "version": version}
    try:
        advisories = {}
        while True:
            request = urllib.request.Request("https://api.osv.dev/v1/query", data=json.dumps(payload).encode(),
                                             headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(request, timeout=45) as response:
                data = json.load(response)
            advisories.update({v["id"]: v for v in data.get("vulns", []) if not v.get("withdrawn")})
            if not data.get("next_page_token"):
                break
            payload["page_token"] = data["next_page_token"]
        return {"ecosystem": ecosystem, "name": name, "version": version,
                "advisories": [{"id": v["id"], "summary": v.get("summary"),
                                 "aliases": v.get("aliases", []), "severity": v.get("severity", []),
                                 "affected": v.get("affected", []), "references": v.get("references", [])}
                                for v in advisories.values()]}
    except Exception as error:
        return {"ecosystem": ecosystem, "name": name, "version": version,
                "error": type(error).__name__ + ": " + str(error)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fail-on-findings", action="store_true")
    args = parser.parse_args()
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(fetch, packages()))
    output = ROOT / "target/security-dependency-audit.json"
    output.write_text(json.dumps({"queried_at": datetime.now(timezone.utc).isoformat(),
                                 "results": results}, indent=2), encoding="utf-8")
    print(json.dumps({"packages": len(results), "errors": sum("error" in r for r in results),
                      "affected": [{"package": f'{r["ecosystem"]}:{r["name"]}@{r["version"]}',
                                    "ids": [a["id"] for a in r["advisories"]]}
                                   for r in results if r.get("advisories")]}, indent=2))
    raise SystemExit(1 if any("error" in r or (args.fail_on_findings and r.get("advisories"))
                             for r in results) else 0)
