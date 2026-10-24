"""Torch-free RT-DETR publisher RGB square resize and 0..1 rescaling."""
import numpy as np
from PIL import Image


def preprocess_rtdetr(image, size=640):
    rgb = image.convert('RGB').resize((size,size), Image.Resampling.BILINEAR)
    return np.ascontiguousarray((np.asarray(rgb, dtype=np.float32)/255.).transpose(2,0,1))
