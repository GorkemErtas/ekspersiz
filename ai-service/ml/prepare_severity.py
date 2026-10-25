"""Build auditable, expert-labeled *damage-region* severity crops from HITL CC0.

No heuristic severity labels are inferred from damage category, size, or model score.
Never reads a test split and never accepts unverifiable Roboflow/Kaggle relabels.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from PIL import Image

from app.vision.severity import LABELS, crop_damage

SOURCE_URL = "https://humansintheloop.org/resources/datasets/car-parts-and-car-damages-dataset/"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(coco_dir: Path, labels_path: Path, output: Path) -> dict:
    coco_dir, labels_path, output = coco_dir.resolve(), labels_path.resolve(), output.resolve()
    if output.exists():
        raise ValueError("Use an empty/new output directory")
    labels = json.loads(labels_path.read_text(encoding="utf-8"))
    if labels.get("source_license") != "HITL_CC0" or labels.get("source_url") != SOURCE_URL:
        raise ValueError("Unreviewed image license/source")
    if labels.get("guideline_version") != "visible-severity-v1":
        raise ValueError("Severity grading protocol must be reviewed and versioned")
    if not isinstance(labels.get("rows"), list):
        raise ValueError("Missing severity review records")

    documents = {split: json.loads((coco_dir / f"{split}.json").read_text(encoding="utf-8"))
                 for split in ("train", "val")}
    images, annotations, roots, groups = {}, {}, {}, {}
    for split, doc in documents.items():
        if doc["info"]["schema_version"] != "hitl-v1":
            raise ValueError("Unexpected HITL source schema")
        root = Path(doc["info"]["source_root"]).resolve()
        roots[split] = root
        images[split] = {r["id"]: r for r in doc["images"] if "damage" in r["tasks"]}
        damage_ids = {c["id"] for c in doc["categories"] if c["task"] == "damage"}
        annotations[split] = {a["id"]: a for a in doc["annotations"]
                              if a["category_id"] in damage_ids and a["image_id"] in images[split]}
        groups[split] = {r["group_id"] for r in images[split].values()}
    if groups["train"] & groups["val"]:
        raise ValueError("Train/validation vehicle-image group overlap")

    staged = []
    seen = set()
    for row in labels["rows"]:
        if not isinstance(row, dict) or row.get("split") not in ("train", "val"):
            raise ValueError("Only reviewed train/validation rows are permitted")
        split = row["split"]
        ann = annotations[split].get(row.get("annotation_id"))
        if ann is None:
            raise ValueError("Unknown damage annotation; never infer severity on part-only images")
        source = images[split][ann["image_id"]]
        key = (split, row["annotation_id"])
        if key in seen:
            raise ValueError("Duplicate severity grade")
        seen.add(key)
        if (row.get("image_sha256") != source["sha256"] or row.get("grade") not in LABELS
                or row.get("human_verified") is not True
                or not row.get("annotator") or not row.get("reviewer")
                or row["annotator"] == row["reviewer"]):
            raise ValueError("Unverified image identity or expert review")
        image_path = (roots[split] / source["file_name"]).resolve()
        if roots[split] not in image_path.parents or digest(image_path) != source["sha256"]:
            raise ValueError("Unexpected or modified source image")
        x, y, width, height = ann["bbox"]
        with Image.open(image_path) as photo:
            image = photo.convert("RGB")
            crop = crop_damage(image, {"x1": x, "y1": y, "x2": x+width, "y2": y+height})
        staged.append((split, row, crop))

    counts = Counter((split, row["grade"]) for split, row, _ in staged)
    for label in LABELS:
        if counts["train", label] < 30 or counts["val", label] < 10:
            raise ValueError("Insufficient independent expert severity labels for " + label)
    output.mkdir(parents=True)
    for split, row, crop in staged:
        folder = output / split / row["grade"]
        folder.mkdir(parents=True, exist_ok=True)
        crop.save(folder / f'{row["image_sha256"][:20]}_{row["annotation_id"]}.png')
    report = {
        "status": "data_prepared_not_model_approved",
        "source": SOURCE_URL, "source_license": "CC0-1.0",
        "label_guideline": labels["guideline_version"],
        "labels_sha256": digest(labels_path),
        "splits_sha256": {s: digest(coco_dir / f"{s}.json") for s in documents},
        "counts": {split: {label: counts[split, label] for label in LABELS} for split in documents},
        "test_touched": False, "production_approved": False,
        "note": "Visible damage appearance only; labels cannot certify structural severity, depth or repair needs."
    }
    (output / "audit.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--coco", type=Path, required=True)
    parser.add_argument("--human-labels", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    a = parser.parse_args()
    print(json.dumps(prepare(a.coco, a.human_labels, a.output), indent=2))


if __name__ == "__main__":
    main()
