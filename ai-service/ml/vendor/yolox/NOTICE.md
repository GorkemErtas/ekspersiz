# YOLOX origin and local changes

Copyright (c) Megvii Inc. and its affiliates. Apache License 2.0; see LICENSE.

Source: https://github.com/Megvii-BaseDetection/YOLOX
Pinned revision: `6ddff4824372906469a7fae2dc3206c7aa4bbaee`.

The five model modules are from the official project. `yolo_head.py` is modified
to import the extracted local utilities, use Python logging, and bound log box
extents to [-10, 10] identically in training/inference to avoid exp overflow. The two box
functions in `utils.py` are extracted from the same revision; meshgrid is a local
PyTorch compatibility wrapper. Optional assignment drawing is not included.
No third-party checkpoints, image augmentation package, torchvision, custom C++
extension, or detector package is included. `ml/model.py` is the EksperSiz
task-aware adaptation; this is not an upstream model or upstream benchmark.
