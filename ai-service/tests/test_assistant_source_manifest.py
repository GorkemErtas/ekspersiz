import json
import tempfile
import unittest
from pathlib import Path

from app.assistant.source_manifest import KnowledgeManifest


class AssistantSourceManifestTest(unittest.TestCase):
    def test_manifest_resolves_sources_and_defaults(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "maintenance").mkdir()
            source = root / "maintenance" / "tire.md"
            source.write_text("# Tire", encoding="utf-8")
            manifest = root / "sources.json"
            manifest.write_text(json.dumps({
                "defaults": {
                    "source_name": "EksperSiz",
                    "authority": "CURATED",
                    "language": "tr",
                    "market": "TR"
                },
                "sources": [{
                    "id": "tire-maintenance-tr",
                    "glob": "maintenance/tire.md",
                    "category": "MAINTENANCE",
                    "valid_from": "2026-10-01"
                }]
            }), encoding="utf-8")

            loaded = KnowledgeManifest.load(root, manifest, "2026-10")

            self.assertEqual(1, len(loaded.sources))
            self.assertEqual(source, loaded.sources[0].path)
            self.assertEqual("2026-10", loaded.sources[0].source_version)
            self.assertEqual("TR", loaded.sources[0].market)
            self.assertEqual("tire-maintenance-tr", loaded.sources[0].slug)
            self.assertEqual("2026-10-01", loaded.sources[0].valid_from.isoformat())

    def test_manifest_rejects_invalid_validity_window(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "source.md").write_text("# Source", encoding="utf-8")
            manifest = root / "sources.json"
            manifest.write_text(json.dumps({
                "sources": [{
                    "id": "invalid-window",
                    "glob": "source.md",
                    "category": "SAFETY",
                    "valid_from": "2026-11-01",
                    "valid_until": "2026-10-01"
                }]
            }), encoding="utf-8")

            with self.assertRaises(ValueError):
                KnowledgeManifest.load(root, manifest, "2026-10")


if __name__ == "__main__":
    unittest.main()
