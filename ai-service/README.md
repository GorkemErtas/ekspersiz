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

## Model-free fast gate (PR #14)

Cheap checks now run before any YOLO initialization:
- Close-up blur and brightness are validated by OpenCV, without constructing
  `DamageAnalyzer` (which still eagerly loads three YOLO checkpoints).
- After the second upload, the mobile app requests the paired validation
  **before** context-image quality; backend direct analyze calls also enforce
  that order, with path-snapshot consistency under the transaction lock.
- A max-896px SIFT precheck rejects identical/recompressed duplicate photos
  and only strongly textured photo pairs with at most one mutual feature match.
- Low-texture and borderline outcomes remain **inconclusive** and go through
  the existing YOLO-assisted, vehicle-cropped SIFT/RANSAC verifier. A fast
  precheck pass is **not** proof of same-vehicle identity and cannot bypass
  the existing final checks.
- The precheck is not a new AI model, cloud dependency, or GPU workload.
  Its CPU overhead is incurred for valid pairs, so savings depend on the
  proportion of obviously invalid submissions. Measure with real photo pairs.

**Accuracy caveat:** even 0–1 SIFT matches cannot conclusively prove that
two photographs show different vehicles; extreme viewpoint/zoom changes may
produce false rejections. Ship only with representative real-photo validation,
and fall back to final verification when visual evidence is weak.

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
- A bounded 64-entry SHA-256 cache prevents redoing expensive
  preflight inference when the exact same photos are checked again by
  the backend. It stores only hashes, validation results and small detection
  boxes, never image contents or model tensors.
- The paired analysis reuses the cached close-up damage and wide-angle
  vehicle boxes, skipping two otherwise repeated YOLO inference passes.
  Context damage and part models still run for localization.

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
