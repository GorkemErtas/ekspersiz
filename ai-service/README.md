# EksperSiz AI Service

## Production pipeline

The production service uses the reviewed CarDD five-class damage detector:

```text
image
  -> yolo11n.pt vehicle detection and primary-vehicle crop
  -> models/candidates/damage_detection_v2_cardd_5class.pt damage detection
  -> models/vehicle_part_best.pt vehicle-part detection
  -> bounding-box overlap matching
  -> deterministic severity and repair recommendation
  -> FastAPI response
```

The detector's class IDs are resolved from its checkpoint names on first image request, not
from a fixed numeric order. The active checkpoint supports `SCRATCH`, `DENT`,
`CRACK`, `BROKEN_PART`, and `BROKEN_GLASS`. `NO_VISIBLE_DAMAGE` is a
deterministic domain result, never a learned damage class.

All three production weights are deployment artifacts ignored by Git and must
be present at the paths above. The service has no runtime model override.

## Two-photo correspondence preflight (PR #13)

Before a two-photo inspection is allowed to enter `PROCESSING`, the backend
calls the AI `/api/v1/validate-pair` endpoint with the close-up and wide shot.
The mobile flow also runs this check immediately after the second upload.

- The wide shot must contain a YOLO-detected vehicle.
- OpenCV SIFT + mutual descriptor matching and RANSAC must find geometrically
  consistent shared details **within the detected vehicle crop**.
- Matches must cover a meaningful area (not only a repeated logo), and, when
  a close-up damage detection exists, support its nearby region.
- Identical image bytes and unrelated or ambiguous photo pairs are rejected
  **before** analysis quota/reservation and Gemini report generation.
- A bounded 64-entry SHA-256 decision cache prevents redoing expensive
  preflight inference when the exact same photos are checked again by
  the backend. The cache holds hashes and results, never image contents.

**Important limitation:** local-feature alignment is evidence of shared
photographed body surface, **not proof of unique vehicle identity**. Smooth
paint, major perspective changes, glare and severe zoom differences may
cause valid photo pairs to be rejected. Users should capture the same damage
and distinctive surrounding details in both shots. This must be tested on
representative real-world paired photos before a release; synthetic CI images
do not validate false-rejection rates. Model weights and thresholds are not changed.

## Detection V2 dataset and training

- Dataset config: `datasets/vehicle_damage_detection_v2/data.yaml`
- Canonical taxonomy: `config/damage_taxonomy.yaml`
- CarDD import mapping: `config/cardd_import.yaml`
- Training command: `python scripts/train_damage_model.py`

Place the untouched CarDD YOLO export under `datasets/raw/cardd` with its
original `train`, `val`, and `test` splits, then run:

```powershell
.\venv\Scripts\python.exe .\scripts\import_cardd_dataset.py
```

The importer validates image/label pairs, preserves the original split, maps
the supported CarDD classes, and writes generated files beneath
`datasets/vehicle_damage_detection_v2`. Tire-flat-only images are quarantined
rather than treated as clean negative examples.

Use the independent `test` split for validation:

```bash
python scripts/evaluate_damage_models.py \
  --data datasets/vehicle_damage_detection_v2/data.yaml \
  --split test \
  --model detection-v2=models/candidates/damage_detection_v2_cardd_5class.pt
```

For manual review of real images:

```bash
python scripts/analyze_damage_errors.py \
  --model detection-v2=models/candidates/damage_detection_v2_cardd_5class.pt
```
