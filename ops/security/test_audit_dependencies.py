"""Offline regressions for the mandatory Java/Python advisory inventory."""
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import audit_dependencies as audit


class DependencyAuditTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        (self.root / "target").mkdir()
        (self.root / "ai-service").mkdir()
        (self.root / "target/security-java-dependencies.txt").write_text(
            "   example:api:jar:1.2.3:compile\n"
            "   example:native:jar:linux-x86_64:2.0.0:runtime\n"
            "   example:test:jar:9.0.0:test\n", encoding="utf-8")
        (self.root / "ai-service/requirements.txt").write_text(
            "fastapi==0.139.2\nhttpx[http2]==0.28.1; python_version >= '3.12'\n",
            encoding="utf-16")
        (self.root / "ai-service/requirements-runtime.txt").write_text(
            "fastapi==0.139.2\npydantic==2.13.4\n", encoding="utf-8-sig")
        root_patch = patch.object(audit, "ROOT", self.root)
        root_patch.start()
        self.addCleanup(root_patch.stop)

    def test_inventory_preserves_java_and_python_without_flutter(self):
        self.assertFalse((self.root / "mobile").exists())
        self.assertEqual(audit.packages(), [
            ("Maven", "example:api", "1.2.3"),
            ("Maven", "example:native", "2.0.0"),
            ("PyPI", "fastapi", "0.139.2"),
            ("PyPI", "httpx", "0.28.1"),
            ("PyPI", "pydantic", "2.13.4"),
        ])

    def test_resolved_python_transitives_are_still_audited(self):
        (self.root / "target/security-python-resolved.json").write_text(
            json.dumps([{"name": "anyio", "version": "4.12.0"}]), encoding="utf-16")
        self.assertIn(("PyPI", "anyio", "4.12.0"), audit.packages())

    def test_missing_required_inventory_fails(self):
        for name in ["target/security-java-dependencies.txt",
                     "ai-service/requirements.txt", "ai-service/requirements-runtime.txt"]:
            file = self.root / name
            content = file.read_bytes()
            file.unlink()
            with self.subTest(file=name), self.assertRaises(FileNotFoundError):
                audit.packages()
            file.write_bytes(content)

    def test_osv_pagination_and_withdrawn_advisories(self):
        responses = [
            {"vulns": [{"id": "ACTIVE"}, {"id": "OLD", "withdrawn": "2026-01-01"}],
             "next_page_token": "page-two"},
            {"vulns": [{"id": "ACTIVE"}, {"id": "SECOND"}]},
        ]
        def response(request, timeout):
            if len(responses) == 1:
                self.assertEqual(json.loads(request.data)["page_token"], "page-two")
            return io.BytesIO(json.dumps(responses.pop(0)).encode())
        with patch.object(audit.urllib.request, "urlopen", side_effect=response):
            result = audit.fetch(("Maven", "example:api", "1.2.3"))
        self.assertEqual([item["id"] for item in result["advisories"]], ["ACTIVE", "SECOND"])

    def test_unavailable_osv_is_an_error_not_a_clean_result(self):
        with patch.object(audit.urllib.request, "urlopen", side_effect=OSError("offline")):
            result = audit.fetch(("PyPI", "fastapi", "0.139.2"))
        self.assertIn("error", result)
        self.assertNotIn("advisories", result)


if __name__ == "__main__":
    unittest.main()
