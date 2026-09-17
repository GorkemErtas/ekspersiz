# Candidate Model Weights

Store evaluated, unpromoted checkpoints here using versioned names such as:

- `damage_detection_v2.pt`
- `damage_segmentation_v1.pt`

Weights are ignored by Git. Nothing in the training or evaluation pipeline copies a candidate over `../best.pt`. Production promotion requires an explicit reviewed deployment action after independent testing and manual error analysis.

