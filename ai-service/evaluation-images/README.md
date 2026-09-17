# Manual Real-World Evaluation Images

Place real review images in this directory; images are ignored by Git. Keep `.gitkeep`, this README, and the header-only `review_manifest.csv` tracked.

The optional manifest fields are:

- `image`: filename relative to this directory.
- `expected_damage`: `true`, `false`, or blank when unknown.
- `expected_types`: canonical classes separated by `|`, for example `SCRATCH|PAINT_DAMAGE`.
- `notes`: manual context or localization observations.

Use the same folder for every compared model. Include clean vehicles, subtle damage, large damage, difficult lighting, different cameras and angles, and known `SCRATCH`/`PAINT_DAMAGE` and `DENT`/`DEFORMATION` cases. Do not commit private evaluation images.

