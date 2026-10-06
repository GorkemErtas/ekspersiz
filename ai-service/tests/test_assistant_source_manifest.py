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
                    "glob": "maintenance/**/*.md",
                    "category": "MAINTENANCE"
                }]
            }), encoding="utf-8")

            loaded = KnowledgeManifest.load(root, manifest, "2026-10")

            self.assertEqual(1, len(loaded.sources))
            self.assertEqual(source, loaded.sources[0].path)
            self.assertEqual("2026-10", loaded.sources[0].source_version)
            self.assertEqual("TR", loaded.sources[0].market)


if __name__ == "__main__":
    unittest.main()
