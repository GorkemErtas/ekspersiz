# Vehicle Damage Segmentation V1 Dataset

This experimental dataset is intentionally empty. Add only real, manually reviewed images and damage polygons. It does not replace production detection.

## Ultralytics YOLO segmentation format

Place matching files in `images/{train,val,test}` and `labels/{train,val,test}`. Each damage instance is one line:

```text
class_id x1 y1 x2 y2 x3 y3 ... xn yn
```

Polygon coordinates are normalized to `[0, 1]`. Use at least three points, keep the polygon ordered around the damage boundary, and create a separate line for each instance.

| ID | Canonical class |
|---:|---|
| 0 | `SCRATCH` |
| 1 | `DENT` |
| 2 | `PAINT_DAMAGE` |
| 3 | `CRACK` |
| 4 | `BROKEN_PART` |
| 5 | `BROKEN_GLASS` |
| 6 | `DEFORMATION` |

`NO_VISIBLE_DAMAGE` is not a segmentation class. Clean vehicle images are negative examples and should have an empty `.txt` label file. Do not fabricate masks.

The canonical mapping lives in [`../../config/damage_taxonomy.yaml`](../../config/damage_taxonomy.yaml). Any external taxonomy requires an explicit reviewed mapping; unknown classes must be rejected rather than guessed.

## Dataset quality

Cover different brands, body styles, colors, viewing angles, lighting, cameras, distances, and damage sizes. Include clean vehicles to measure and reduce false positives. Review polygon boundaries, class balance, small-damage coverage, and the common `SCRATCH`/`PAINT_DAMAGE` and `DENT`/`DEFORMATION` confusions.

Keep each vehicle or photo sequence inside one split. Remove duplicate and near-duplicate leakage and reserve a truly independent test set for final evaluation.

