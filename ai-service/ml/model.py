"""One shared YOLOX-Tiny PAFPN, two heads, one checkpoint and one forward."""
from __future__ import annotations

import torch
from torch import nn
from .vendor.yolox.yolo_pafpn import YOLOPAFPN
from .vendor.yolox.yolo_head import YOLOXHead

TASKS = ('damage', 'part')


class UnifiedYOLOXTiny(nn.Module):
    def __init__(self, counts=(8, 21)):
        super().__init__()
        self.backbone = YOLOPAFPN(depth=.33, width=.375)
        self.heads = nn.ModuleDict({task: YOLOXHead(n, width=.375) for task,n in zip(TASKS,counts)})
        for module in self.modules():
            if isinstance(module, nn.BatchNorm2d):
                module.eps, module.momentum = 1e-3, .03
        for head in self.heads.values():
            head.initialize_biases(.01)

    def forward(self, images, targets=None, task_mask=None):
        features = self.backbone(images)
        if not self.training:
            return tuple(self.heads[t](features) for t in TASKS)
        if targets is None or task_mask is None:
            raise ValueError('Training requires explicit targets and task coverage')
        losses = {}
        for index, task in enumerate(TASKS):
            active = task_mask[:, index].bool()
            if active.any():
                task_features = tuple(f[active] for f in features)
                # The inactive task is never called: no objectness negatives or BN updates.
                losses[task] = self.heads[task](task_features, targets[task][active], images[active])[0]
            else:
                losses[task] = features[0].sum() * 0
        return losses


def load_checkpoint(path, device='cpu'):
    checkpoint = torch.load(path, map_location=device, weights_only=True)
    if checkpoint.get('schema_version') != 'hitl-v1':
        raise ValueError('Unsupported checkpoint schema')
    categories = checkpoint['catalog']['categories']
    counts = tuple(sum(c['task']==t for c in categories) for t in TASKS)
    model = UnifiedYOLOXTiny(counts).to(device)
    model.load_state_dict(checkpoint['model'], strict=True)
    return model, checkpoint
