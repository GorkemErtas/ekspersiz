import json
from collections import Counter, defaultdict
from pathlib import Path
import random

import numpy as np
from PIL import Image, ImageEnhance
import torch
from torch.utils.data import Dataset, WeightedRandomSampler

from app.vision.processing import preprocess


class CocoTasks(Dataset):
    def __init__(self, path, size=416, augment=False, limit_per_task=None):
        self.document = json.loads(Path(path).read_text(encoding='utf-8'))
        self.root = Path(self.document['info']['source_root'])
        self.categories = {c['id']:c for c in self.document['categories']}
        self.images = self.document['images']
        if limit_per_task:
            selected = []
            for task in ('damage','part'):
                selected.extend([r for r in self.images if task in r['tasks']][:limit_per_task])
            self.images = list({r['id']:r for r in selected}.values())
        self.annotations = defaultdict(list)
        for annotation in self.document['annotations']:
            self.annotations[annotation['image_id']].append(annotation)
        self.size, self.augment = size, augment

    def __len__(self):
        return len(self.images)

    def __getitem__(self,index):
        row = self.images[index]
        with Image.open(self.root/row['file_name']) as source:
            image = source.convert('RGB')
        flip = self.augment and random.random()<.5
        if flip:
            image = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if self.augment:
            image = ImageEnhance.Brightness(image).enhance(random.uniform(.85,1.15))
        pixels, ratio = preprocess(image,self.size)
        targets = {t:[] for t in ('damage','part')}
        for obj in self.annotations[row['id']]:
            c = self.categories[obj['category_id']]
            x,y,w,h = obj['bbox']
            if flip:
                x = image.width-x-w
            targets[c['task']].append([c['task_index'],(x+w/2)*ratio,(y+h/2)*ratio,w*ratio,h*ratio])
        return torch.from_numpy(pixels), targets, [t in row['tasks'] for t in ('damage','part')], row['id']

    def sampler(self, generator):
        frequency = Counter(c for r in self.images for c in r['labels'])
        task_counts = Counter(t for r in self.images for t in r['tasks'])
        weights = []
        for row in self.images:
            rarity = sum(1/(frequency[c]**.5) for c in row['labels'])/max(len(row['labels']),1)
            weights.append(max(rarity,1e-3)/min(task_counts[t] for t in row['tasks']))
        # Normalize each task contribution, balancing tasks as well as rare classes.
        totals = {t:sum(w for w,r in zip(weights,self.images) if t in r['tasks']) for t in task_counts}
        weights = [w/min(totals[t] for t in r['tasks']) for w,r in zip(weights,self.images)]
        return WeightedRandomSampler(weights,len(weights),replacement=True,generator=generator)


def collate(samples):
    images, targets, masks, ids = zip(*samples)
    padded = {}
    for task in ('damage','part'):
        count = max(1,max(len(t[task]) for t in targets))
        result = torch.zeros((len(samples),count,5),dtype=torch.float32)
        for i,target in enumerate(targets):
            if target[task]:
                result[i,:len(target[task])] = torch.tensor(target[task])
        padded[task] = result
    return torch.stack(images), padded, torch.tensor(masks,dtype=torch.bool), ids
