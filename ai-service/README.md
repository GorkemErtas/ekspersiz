# EksperSiz AI Service and ML Experiments

## Production pipeline

Production remains unchanged:

```text
image
  -> general YOLO vehicle detection and primary-vehicle crop
  -> models/best.pt damage object detection
  -> models/vehicle_part_best.pt vehicle-part detection
  -> bounding-box overlap matching
  -> deterministic severity and repair recommendation
  -> FastAPI response
  -> Spring Boot persistence and Gemini report
```

Image brightness, blur, recognizable-vehicle presence, and vehicle framing are validated before quota reservation. A successful inference with no damage remains `NO_VISIBLE_DAMAGE` / `NONE` / `NO_ACTION`. `NO_VISIBLE_DAMAGE` is never a learned damage class.

## Experimental pipelines

### Model A — Damage Detection V2

- Dataset: `datasets/vehicle_damage_detection_v2`
- Base model: the existing `yolo11n.pt`
- Default run: `training-runs/damage-detection-v2`
- Candidate destination after review: `models/candidates/damage_detection_v2.pt`

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

Read each dataset README before adding data. Keep the canonical class order in `config/damage_taxonomy.yaml`. Use real images and reviewed YOLO annotations only. Clean vehicles are negative examples with empty label files.

Never mix near-duplicates or images from the same vehicle sequence across train, validation, and test splits. Keep the test split independent and untouched until final comparison.

## 2. Train Detection V2

From `ai-service`:

```bash
python scripts/train_damage_model.py
```

Important settings are configurable:

```bash
python scripts/train_damage_model.py --epochs 100 --batch 8 --imgsz 640 --patience 18 --seed 42 --device auto --name damage-detection-v2
```

CUDA device 0 is selected when available and CPU is the fallback. Training is deterministic where supported, performs validation, enables early stopping, and writes plots and metrics into a versioned Ultralytics run directory. It never copies weights into `models/best.pt`.

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
  --model detection-v2=models/candidates/damage_detection_v2.pt
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

The current production checkpoint exposes only `BROKEN_PART`, `DENT`, and `SCRATCH`, in a different numeric order from the canonical V2 taxonomy. When multiple models are supplied, the evaluator therefore builds ignored comparison views of the same test images, remaps label IDs for each checkpoint, and calculates comparison metrics over the canonical classes shared by every model. Each JSON result records that `evaluation_scope`. Run Detection V2 by itself as well to measure all seven canonical classes; do not interpret the shared three-class aggregate as full-taxonomy performance.

```bash
python scripts/evaluate_damage_models.py \
  --task detect \
  --data datasets/vehicle_damage_detection_v2/data.yaml \
  --split test \
  --model detection-v2=models/candidates/damage_detection_v2.pt
```

## 5. Real-world error analysis

Place manually selected images in `evaluation-images` and optionally complete `review_manifest.csv`. Compare old and new detection models on exactly the same images:

```bash
python scripts/analyze_damage_errors.py \
  --model production=models/best.pt \
  --model detection-v2=models/candidates/damage_detection_v2.pt
```

The utility saves annotated images plus CSV/JSON review tables. It flags clean-image false positives, low-confidence false positives, missed known damage, and incorrect damage types when manifest expectations exist. Use annotated outputs to review localization, small missed damage, `SCRATCH` vs `PAINT_DAMAGE`, and `DENT` vs `DEFORMATION`. Run segmentation candidates separately and inspect the emitted mask/image area ratios.

## 6. Manual production promotion

Promotion is intentionally manual:

1. Train without touching production weights.
2. Review validation metrics and training plots.
3. Evaluate once on the independent test split.
4. Compare production and candidate per class.
5. Review real-world false positives, misses, class confusion, and localization.
6. Copy the accepted run weight to `models/candidates` and record the experiment settings/results.
7. Back up `models/best.pt` and replace it only through an explicit reviewed deployment action.
8. Run AI-service tests and an end-to-end inspection smoke test before release.

Training and evaluation scripts never overwrite `models/best.pt`.
