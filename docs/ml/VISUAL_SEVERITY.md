# Visual damage severity — licensed training and gated integration (25 Oct 2026)

## Status: CODE INTEGRATED, MODEL NOT TRAINED / NOT APPROVED
- Master supports an **optional severity.onnx** head in an `ensemble-v1` bundle.
- Without a human-reviewed checkpoint, severity remains `UNKNOWN`, as before.
- Both image analysis and bundle release approval remain off. No deployment, payment, schema or Flutter behavior changed.
- Model outputs only **visual appearance** `MINOR`, `MODERATE`, `SEVERE`, not structural damage, repair eligibility, safety, insurance claim or replacement decision.

## Decision on candidate datasets
| Candidate | Public license / source | Decision |
| --- | --- | --- |
| **HITL Car Parts and Damages** | Original publisher [Humans in the Loop](https://humansintheloop.org/resources/datasets/car-parts-and-car-damages-dataset/) CC0-1.0; source history already audited | **Approved original-image source**. Does **not** contain severity labels. Expert review of damage instances required. |
| Roboflow CSP650 Car Damage Severity Assessment (1,692, 3 categories) | [CC BY 4.0 declared](https://universe.roboflow.com/csp650-5tzt9/car-damage-severity-assessment); original image ownership/unseen training split cannot be verified | Candidate research only; **DO NOT TRAIN** until the uploader demonstrates rights to original images, review policy, split integrity and granted commercial rights. Image-level category differs from per-instance grade. |
| Roboflow Rashad Damage Severity (2,862, includes 'Unlabeled') | [CC BY 4.0 declared](https://universe.roboflow.com/rashad-eqz8p/damage-severity-6ya6c-apqrf); no project description/provenance | **DO NOT TRAIN** until rights, annotation and 'Unlabeled' semantics are verified. |
| Kaggle car-damage-severity-dataset (about 1,509 photos in literature) | [Kaggle link](https://www.kaggle.com/datasets/prajwalbhamere/car-damage-severity-dataset); commercial license/source image rights **not verified** | **DO NOT TRAIN**. |
| CarDD copies labeled as severity | Original [CarDD](https://cardd-ustc.github.io/) has an access licensing form, commercial clearance unverified | **DO NOT TRAIN**, including mirrors/Roboflow imports. |
| Raqabah car accident severity | [Zenodo](https://zenodo.org/records/20247785); traffic-crash scene labels, not scratch/dent region grading. License metadata was not reliably verifiable | Unsuitable for this task; **DO NOT TRAIN**. |

No third-party public severity dataset was confirmed *both* commercially cleared **and** an appropriate per-damage region supervision source. This is a deliberate stop rather than re-labeling images or inheriting a dubious CC BY claim. The best rights-auditable route at present is to independently grade original CC0 HITL damage polygons using a reviewed visual rubric.

## Grade definition and labeling
Version `visible-severity-v1`: grade only the observable *local* cosmetic appearance after seeing the full source image and the proposed damage ROI. The expert annotator and independent reviewer must agree; uncertain or insufficient-image cases **must not be forced** into a class.
- `MINOR`: isolated superficial-looking defect within a limited visible region; depth cannot be inferred.
- `MODERATE`: larger/multiple clear visible cosmetic changes in that local ROI, without evidence supporting an extent-of-structural-damage claim.
- `SEVERE`: pronounced *visible* damage to the observed region; does **not** certify structural severity or required repair. If ungradable: exclude from supervised training and preserve `UNKNOWN` for inference.

A qualified automotive reviewer must approve these definitions before production training; these are preliminary label instructions rather than an engineering severity standard. Do not automatically infer grades from damage class (e.g. `Broken part`), damaged-pixel ratio, detection score or synthetic pseudo-labels.

Suggested minimum for a meaningful experiment: substantially more than the script's **technical gate** of 30 train and 10 validation instances per grade; prioritize hundreds of independent vehicle/incident instances per grade and a separately acquired blind field test, stratified by damage type, photo quality and car model. Grade disagreement should be recorded, not erased.

## Source-safe preparation
First obtain expert review labels for **HITL existing damage annotations**. `train.json` and `val.json` contain the source image SHA-256 and annotation IDs. The label file (outside git) format:
```json
{
  "source_license": "HITL_CC0",
  "source_url": "https://humansintheloop.org/resources/datasets/car-parts-and-car-damages-dataset/",
  "guideline_version": "visible-severity-v1",
  "rows": [
    {"split":"train","image_sha256":"REAL_64_CHARACTER_HASH","annotation_id":123,
     "grade":"MINOR","annotator":"qualified-person-A","reviewer":"qualified-person-B",
     "human_verified":true}
  ]
}
```
Use **actual** image hash and COCO annotation ID. Never invent/auto-populate them. Each instance must carry a human grade plus independent review. The script rejects changed source images, unknown annotations, repeated grades, rejected license, missing verification, test rows, and insufficient class counts. Images and trained checkpoints remain out of Git.

```bash
cd ai-service
python -m pip install -r requirements-severity.txt
python -m ml.prepare_severity --coco datasets/hitl-coco --human-labels datasets/severity/reviewed-labels.json --output datasets/severity-reviewed-v1
```

## Candidate model
**MobileNetV3-Small (timm), publisher Apache-2.0 pretrained weights.**
Official [model card](https://huggingface.co/timm/mobilenetv3_small_100.lamb_in1k), SHA-256 for exact `model.safetensors`:
`46d2c063b18125884c48937afa4c49e18128869e52e8db96df48bf0a4d7ff697`.
Code/weights licensed separately from images. Training uses offline safetensors, replaces the 1000-class head with 3 classes, evaluates per-class precision/recall/macro F1, exports ONNX and checks parity. No ultralytics or proprietary detection model. This is a **lightweight technical candidate** for Railway, **not** a measured winner.

```bash
python -m ml.train_severity --data datasets/severity-reviewed-v1 \
  --pretrained models/reviewed-mobilenet/model.safetensors \
  --output training-runs/severity-v1
python -m unittest tests.test_vision_severity tests.test_prepare_severity
```
Training/export requires correctly annotated files and preinstalled offline-reviewed dependencies; no real training results are claimed. `severity-manifest-DRAFT.json` is deliberately disabled and unapproved.

## Runtime contract and production gate
Current DETR ensemble continues with the existing damage and part graphs. Optional `severity.onnx` classifies **detected damage crops** (max 12), sequentially on CPU and only if the root ensemble `production_approved=true` **and** `severity.enabled=true`, `severity.approved=true`, `severity.validation_calibrated=true`, correct SHA-256, class order and preprocessing are present. Otherwise existing `UNKNOWN` remains the output. An uncertain or invalid crop and any failed/unconfident classification keeps the image-level severity `UNKNOWN`. All accepted local grades combine conservatively as the most visually pronounced, but **never** infer `NONE`, structural damage or definitive repair.

Before approval, obtain a **new untouched expert-labelled blind test**, verify confusion/macro F1, rare-class errors, user-camera blur/reflections, classifier calibration/reject rate, false reassurance risk on `SEVERE`, and grading agreement. Test on **predicted ROI crops**, not just ideal ground-truth crops. Validate combined detection->severity precision/recall and Railway CPU/RAM with existing E5/Java services. The detector itself still fails its production threshold, so severity work does not enable the product.

Conservative alternative: if these validation requirements cannot be satisfied, leave `damageSeverity=UNKNOWN` and show the observable damage description with a professional-inspection recommendation.
