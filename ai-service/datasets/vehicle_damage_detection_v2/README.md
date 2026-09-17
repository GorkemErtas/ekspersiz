# Vehicle Damage Detection V2 Dataset

This directory is intentionally empty. Add only real, manually reviewed vehicle images and YOLO object-detection annotations.

## Layout

Place matching files in `images/{train,val,test}` and `labels/{train,val,test}`. An image named `car_001.jpg` uses `car_001.txt` as its label file.

Each non-empty label line uses normalized YOLO detection coordinates:

```text
class_id center_x center_y width height
```

All four coordinates must be in `[0, 1]`. Use one line per visible damage instance.

| ID | Canonical class |
|---:|---|
| 0 | `SCRATCH` |
| 1 | `DENT` |
| 2 | `PAINT_DAMAGE` |
| 3 | `CRACK` |
| 4 | `BROKEN_PART` |
| 5 | `BROKEN_GLASS` |
| 6 | `DEFORMATION` |

`NO_VISIBLE_DAMAGE` is a domain result, not a learned object class. Include clean vehicle images as intentional negative examples with an empty `.txt` label file. Never draw a whole-vehicle “no damage” box.

The canonical mapping lives in [`../../config/damage_taxonomy.yaml`](../../config/damage_taxonomy.yaml). External classes must be mapped explicitly with a reviewed configuration based on [`../../config/external_class_remap.example.yaml`](../../config/external_class_remap.example.yaml). Do not edit or remap labels by assumption.

## Dataset quality

Include different brands, body styles, colors, camera devices, front/rear/side/diagonal angles, daylight/cloudy/garage lighting, close and medium distances, small and large damage, and clean vehicles. Inspect class balance and annotation quality manually.

Keep images from the same vehicle or photo sequence in one split to prevent leakage. Avoid duplicates and near-duplicates across splits. Preserve a truly independent test set and do not use it for training decisions.

