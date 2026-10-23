"""Audited production artifacts. Updating this contract requires a model review.

BROKEN_PART is a legacy wire name for CarDD's `lamp broken`, not arbitrary
broken components. PAINT_DAMAGE/DEFORMATION remain historical API values only.
"""
from hashlib import file_digest
from pathlib import Path

DAMAGE_CLASSES = ("SCRATCH", "DENT", "CRACK", "BROKEN_PART", "BROKEN_GLASS")
PART_CLASSES = (
    "Back-bumper", "Back-door", "Back-wheel", "Back-window", "Back-windshield",
    "Fender", "Front-bumper", "Front-door", "Front-wheel", "Front-window",
    "Grille", "Headlight", "Hood", "License-plate", "Mirror", "Quarter-panel",
    "Rocker-panel", "Roof", "Tail-light", "Trunk", "Windshield",
)
ARTIFACT_SHA256 = {
    "vehicle": "0ebbc80d4a7680d14987a577cd21342b65ecfd94632bd9a8da63ae6417644ee1",
    "damage": "3f5f77fe59243695cc0a42e0bff9e283c5fc0970793d8d6d6010db959983c52b",
    "part": "5d1bed6466dfe92b3506b5bbcba50003d8ed56237d908c8709e9bb1e1f92ef71",
}


def verify_artifact(path: Path, role: str) -> None:
    with path.open("rb") as source:
        digest = file_digest(source, "sha256").hexdigest()
    if digest != ARTIFACT_SHA256[role]:
        raise RuntimeError(f"Unreviewed {role} checkpoint: model contract mismatch.")


def verify_names(names, expected: tuple[str, ...]) -> None:
    actual = names if isinstance(names, dict) else dict(enumerate(names))
    if actual != dict(enumerate(expected)):
        raise RuntimeError("Checkpoint classes do not match the audited model contract.")
