# EksperSiz AI Service and ML Experiments

## Production pipeline

The reviewed CarDD five-class checkpoint is the active production damage detector:

```text
image
  -> general YOLO vehicle detection and primary-vehicle crop
  -> models/candidates/damage_detection_v2_cardd_5class.pt damage object detection
  -> models/vehicle_part_best.pt vehicle-part detection
  -> bounding-box overlap matching
  -> deterministic severity and repair recommendation
  -> FastAPI response
  -> Spring Boot persistence and Gemini report
```

Image brightness, blur, recognizable-vehicle presence, and vehicle framing are validated before quota reservation. A successful inference with no damage remains `NO_VISIBLE_DAMAGE` / `NONE` / `NO_ACTION`. `NO_VISIBLE_DAMAGE` is never a learned damage class.

The detector's class IDs are never interpreted using a hardcoded numeric order. At startup, the service reads the checkpoint's class names, normalizes them to the application enum values, and rejects malformed, duplicate, unknown, or unsupported names. The active checkpoint exposes `SCRATCH`, `DENT`, `CRACK`, `BROKEN_PART`, and `BROKEN_GLASS`. The seven-class application taxonomy remains unchanged; `PAINT_DAMAGE` and `DEFORMATION` stay available for stored data and future compatible models.

`DAMAGE_MODEL_PATH` can select another reviewed local checkpoint. Relative values are resolved from `ai-service`; for example, `DAMAGE_MODEL_PATH=models/best.pt` selects the preserved previous checkpoint for rollback. The configured checkpoint must still pass the startup class-name validation.

## Experimental pipelines

### Model A — Damage Detection V2 (ACTIVE)

- Dataset config: `datasets/vehicle_damage_detection_v2/data.yaml`
- Output classes: `SCRATCH`, `DENT`, `CRACK`, `BROKEN_PART`, `BROKEN_GLASS`
- Base model: the existing `yolo11n.pt`
- Default run: `training-runs/damage-detection-v2-cardd-5class-640`
- Active production checkpoint: `models/candidates/damage_detection_v2_cardd_5class.pt`

The application taxonomy remains the seven classes in `config/damage_taxonomy.yaml`. This first CarDD model has a five-class output head because CarDD has no supported examples for `PAINT_DAMAGE` or `DEFORMATION`. Those application damage types remain valid for legacy models, future datasets, backend records, and Flutter display.

### Model B — Damage Segmentation V1 (EXPERIMENTAL)

- Dataset: `datasets/vehicle_damage_segmentation_v1`
- Base model: `yolo11n-seg.pt`, supplied separately before training
- Default run: `training-runs/damage-segmentation-v1`
- Candidate destination after review: `models/candidates/damage_segmentation_v1.pt`

Segmentation does not participate in production inference yet. Its intended future flow is:

```text
vehicle detection
  -> damage instance segmentation
  -> vehicle-part localization
  -> damage-mask / part-region intersection
  -> structured result
```

`experiments/mask_metrics.py` contains isolated mask/part intersection and damage-area/part-area calculations for later research. Production severity remains deterministic and model confidence is not treated as severity. A secondary damage classifier is only a possible future experiment if segmentation classification proves insufficient; it is not implemented to avoid extra latency and complexity.

## 1. Populate datasets

Read each dataset README before adding data. Keep `config/damage_taxonomy.yaml` as the application-level source of truth. Each experiment may declare a reviewed subset and contiguous model-specific IDs in its own `data.yaml`. Use real images and reviewed YOLO annotations only. Clean vehicles are negative examples with empty label files.

Never mix near-duplicates or images from the same vehicle sequence across train, validation, and test splits. Keep the test split independent and untouched until final comparison.

### Import the manually downloaded CarDD dataset

Place the untouched CarDD YOLO export under `datasets/raw/cardd` with its original `train`, `val`, and `test` splits, then run this command from `ai-service` in PowerShell:

```powershell
.\venv\Scripts\python.exe .\scripts\import_cardd_dataset.py
```

The reviewed mapping in `config/cardd_import.yaml` validates its model classes against the shared `config/damage_taxonomy.yaml`, then assigns contiguous CarDD model IDs. The importer validates every image/label pair and YOLO detection line, preserves the original splits, and writes generated files beneath `datasets/vehicle_damage_detection_v2/images/{split}/cardd` and `labels/{split}/cardd`.

CarDD `tire flat` annotations are dropped. Images that also contain a supported damage remain in the dataset with their supported annotations. Images containing only `tire flat` are excluded from training and copied to `datasets/vehicle_damage_detection_v2/quarantine/cardd` for review; they are never converted into clean negative examples. The deterministic summary is written to `datasets/vehicle_damage_detection_v2/cardd-import-report.json`.

The importer never writes to `datasets/raw/cardd`. Re-running it replaces only generated `cardd` subdirectories, removing stale CarDD output while preserving other Detection V2 sources. Raw data, generated images/labels, quarantine files, and the generated report remain ignored by Git.

## 2. Train Detection V2

From `ai-service`:

```bash
python scripts/train_damage_model.py
```

Important settings are configurable:

```bash
python scripts/train_damage_model.py --epochs 100 --batch 8 --imgsz 640 --patience 20 --seed 42 --device auto --name damage-detection-v2-cardd-5class-640
```

Before loading the model, the script validates all train/validation/test image-label pairs, the five-class range, annotation shape, normalized coordinates, and portable dataset paths. The dataset YAML omits `path`, causing both the custom validator and Ultralytics to resolve split paths from the YAML directory. CUDA device 0 is selected when available and CPU is the fallback. Training is deterministic where supported, performs validation, enables early stopping, and writes `weights/best.pt`, `weights/last.pt`, plots, and metrics under `training-runs/damage-detection-v2-cardd-5class-640`. It never copies weights into `models/best.pt`.

## 3. Train Segmentation V1

Place an appropriate pretrained Ultralytics segmentation checkpoint at `ai-service/yolo11n-seg.pt`, or pass its local path explicitly. The script will not silently substitute a detection checkpoint.

```bash
python scripts/train_damage_segmentation.py --model yolo11n-seg.pt
```

The same epochs, batch, image size, patience, seed, workers, device, project, and run-name options are available.

## 4. Validate and compare models

Use validation during iteration. Use the independent `test` split for final old/new comparison:

```bash
python scripts/evaluate_damage_models.py \
  --task detect \
  --data datasets/vehicle_damage_detection_v2/data.yaml \
  --split test \
  --model production=models/best.pt \
  --model detection-v2=models/candidates/damage_detection_v2_cardd_5class.pt
```

Evaluate segmentation separately:

```bash
python scripts/evaluate_damage_models.py \
  --task segment \
  --data datasets/vehicle_damage_segmentation_v1/data.yaml \
  --split test \
  --model segmentation-v1=models/candidates/damage_segmentation_v1.pt
```

The evaluator stores aggregate precision, recall, mAP50, mAP50-95, per-class metrics, and Ultralytics plots/confusion matrices under `evaluation-runs`. Review every class; do not promote a model from one aggregate mAP number.

The previous production checkpoint exposes only `BROKEN_PART`, `DENT`, and `SCRATCH`, in a different numeric order from the CarDD checkpoint. When multiple models are supplied, the evaluator reads the dataset's model-specific class names, builds ignored comparison views of the same test images, remaps label IDs for each checkpoint, and calculates metrics over the semantically shared `SCRATCH`, `DENT`, and `BROKEN_PART` classes. Each JSON result records that `evaluation_scope`. Run Detection V2 by itself as well to measure all five CarDD classes; do not interpret the shared three-class aggregate as full candidate performance.

```bash
python scripts/evaluate_damage_models.py \
  --task detect \
  --data datasets/vehicle_damage_detection_v2/data.yaml \
  --split test \
  --model detection-v2=models/candidates/damage_detection_v2_cardd_5class.pt
```

## 5. Real-world error analysis

Place manually selected images in `evaluation-images` and optionally complete `review_manifest.csv`. Compare old and new detection models on exactly the same images:

```bash
python scripts/analyze_damage_errors.py \
  --model production=models/best.pt \
  --model detection-v2=models/candidates/damage_detection_v2_cardd_5class.pt
```

The utility saves annotated images plus CSV/JSON review tables. It flags clean-image false positives, low-confidence false positives, missed known damage, and incorrect damage types when manifest expectations exist. Use annotated outputs to review localization, small missed damage, `SCRATCH` vs `PAINT_DAMAGE`, and `DENT` vs `DEFORMATION`. Run segmentation candidates separately and inspect the emitted mask/image area ratios.

## 6. Production selection and rollback

Damage Detection V2 was promoted after independent CarDD test evaluation and shared-class comparison. The service now selects `models/candidates/damage_detection_v2_cardd_5class.pt` by default and keeps `models/best.pt` unchanged as the previous checkpoint.

To run the previous checkpoint temporarily in PowerShell, set the override before starting FastAPI:

```powershell
$env:DAMAGE_MODEL_PATH = "models/best.pt"
```

Remove the override to return to the default promoted checkpoint:

```powershell
Remove-Item Env:DAMAGE_MODEL_PATH
```

Checkpoint files remain deployment artifacts and are ignored by Git. Each deployment must provision the selected weight at the documented path. Training and evaluation scripts never overwrite either production or rollback weights.
