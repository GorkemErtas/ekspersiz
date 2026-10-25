import json
from pathlib import Path
import tempfile
import unittest

from ml.prepare_severity import SOURCE_URL, prepare


class SeverityDatasetSafetyTest(unittest.TestCase):
    def test_no_unreviewed_data_can_be_prepared(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            coco = root / "coco"
            coco.mkdir()
            doc = {"info": {"schema_version": "hitl-v1", "source_root": str(root)},
                   "images": [], "annotations": [],
                   "categories": [{"id": 1, "task": "damage"}]}
            (coco / "train.json").write_text(json.dumps(doc), encoding="utf-8")
            (coco / "val.json").write_text(json.dumps(doc), encoding="utf-8")
            labels = root / "labels.json"
            valid = {"source_license": "HITL_CC0", "source_url": SOURCE_URL,
                     "guideline_version": "visible-severity-v1", "rows": []}
            labels.write_text(json.dumps(dict(valid, source_license="UNKNOWN")), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Unreviewed"):
                prepare(coco, labels, root / "output")
            labels.write_text(json.dumps(dict(valid, rows=[{"split": "test", "grade": "SEVERE"}])), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "train/validation"):
                prepare(coco, labels, root / "output")
            labels.write_text(json.dumps(valid), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Insufficient"):
                prepare(coco, labels, root / "output")
            self.assertFalse((root / "output").exists())


if __name__ == "__main__":
    unittest.main()
