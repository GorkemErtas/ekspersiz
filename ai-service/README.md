# EksperSiz AI Service

## Production pipeline

The production service uses the reviewed CarDD five-class damage detector:

```text
image
  -> existing brightness/blur and supported-file validation
  -> yolo11n.pt automobile-only evidence gate and primary-car crop
     (partial car candidate + corroborating parts: keep the full input image)
  -> models/candidates/damage_detection_v2_cardd_5class.pt damage detection
  -> models/vehicle_part_best.pt vehicle-part detection
  -> overlap, part confidence, semantic compatibility and ambiguity checks
  -> optional FRONT/REAR conflict clears the part to UNKNOWN
  -> visible findings with UNKNOWN severity and no established repair action
  -> FastAPI response
```

Checkpoint hashes and exact class names are checked against `app/model_contract.py`
before serving analysis. The active checkpoint supports `SCRATCH`, `DENT`,
`CRACK`, `BROKEN_PART` (CarDD lamp breakage only), and `BROKEN_GLASS`. `NO_VISIBLE_DAMAGE` is a
deterministic domain result, never a learned damage class.

See [the audited class mappings, acceptance rules and limitations](../docs/ml/CAR_ANALYSIS_RELIABILITY.md).
Run `python scripts/audit_production_models.py` from `ai-service` to audit local
artifacts and available dataset YAMLs without training or modifying weights.

All three production weights are deployment artifacts ignored by Git and must
be present at the paths above. The service has no runtime model override.

The current mobile flow uploads only `image` and forwards `vehicle_region` through
the backend. `context_image` / `analyze_pair` remain available only for explicit
legacy two-photo requests. See [single-photo rollout and regression notes](../docs/SINGLE_PHOTO_ANALYSIS.md).

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
