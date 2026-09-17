from __future__ import annotations

import numpy as np


def damage_part_intersection_ratio(
    damage_mask: np.ndarray,
    part_mask: np.ndarray,
) -> float:
    """Fraction of a damage mask that lies inside a candidate vehicle part."""
    damage, part = _validated_masks(damage_mask, part_mask)
    damage_area = int(damage.sum())
    if damage_area == 0:
        return 0.0
    return float(np.logical_and(damage, part).sum() / damage_area)


def damage_to_part_area_ratio(
    damage_mask: np.ndarray,
    part_mask: np.ndarray,
) -> float:
    """Damage/part area signal for future severity research, not production severity."""
    damage, part = _validated_masks(damage_mask, part_mask)
    part_area = int(part.sum())
    if part_area == 0:
        return 0.0
    return float(np.logical_and(damage, part).sum() / part_area)


def _validated_masks(
    damage_mask: np.ndarray,
    part_mask: np.ndarray,
) -> tuple[np.ndarray, np.ndarray]:
    damage = np.asarray(damage_mask, dtype=bool)
    part = np.asarray(part_mask, dtype=bool)
    if damage.ndim != 2 or part.ndim != 2:
        raise ValueError("Damage and part masks must be two-dimensional.")
    if damage.shape != part.shape:
        raise ValueError("Damage and part masks must have the same shape.")
    return damage, part

