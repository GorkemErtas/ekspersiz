# Vehicle Damage Detection V2 - CarDD Five-Class Baseline

Generated CarDD data lives in source-specific `cardd` subdirectories and retains the original train/validation/test split. Raw CarDD files remain untouched under `datasets/raw/cardd`.

## Layout

The active `data.yaml` points to `images/{train,val,test}/cardd`; matching labels live under `labels/{train,val,test}/cardd`. An image named `car_001.jpg` uses `car_001.txt` as its label file.

Each non-empty label line uses normalized YOLO detection coordinates:

```text
class_id center_x center_y width height
```

All four coordinates must be in `[0, 1]`, and width and height must be greater than zero. Use one line per visible damage instance.

| Model ID | CarDD baseline output class |
|---:|---|
| 0 | `SCRATCH` |
| 1 | `DENT` |
| 2 | `CRACK` |
| 3 | `BROKEN_PART` |
| 4 | `BROKEN_GLASS` |

These IDs belong to this model head. The application taxonomy in [`../../config/damage_taxonomy.yaml`](../../config/damage_taxonomy.yaml) remains seven classes and still includes `PAINT_DAMAGE` and `DEFORMATION`. CarDD does not provide supported training examples for those two classes, so this baseline cannot output them.

`NO_VISIBLE_DAMAGE` is a domain result, not a learned object class. Clean vehicle images may be intentional negative examples with empty `.txt` label files, but tire-flat-only CarDD images are quarantined rather than treated as clean.

The explicit CarDD source-to-application-to-model mapping lives in [`../../config/cardd_import.yaml`](../../config/cardd_import.yaml). Do not edit or remap labels by assumption.

## Dataset quality

Future sources should cover different brands, body styles, colors, camera devices, front/rear/side/diagonal angles, daylight/cloudy/garage lighting, close and medium distances, small and large damage, and clean vehicles. Inspect class balance and annotation quality manually.

Keep images from the same vehicle or photo sequence in one split to prevent leakage. Avoid duplicates and near-duplicates across splits. Preserve a truly independent test set and do not use it for training decisions.

The manually downloaded CarDD source is imported with `scripts/import_cardd_dataset.py`. The importer preserves CarDD's original splits and places generated data in the `cardd` subdirectories. See the AI-service README for the PowerShell command and quarantine behavior.
