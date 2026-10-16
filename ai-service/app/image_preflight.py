"""CPU-only image gates; importing this module never imports YOLO or PyTorch.

The pair gate rejects only near-duplicates or strongly textured pairs with
virtually no mutual visual correspondence. A non-rejection is NOT approval:
the existing cropped-vehicle SIFT/RANSAC and damage-region verifier must run.
"""
from io import BytesIO

import cv2
import numpy as np
from PIL import Image, UnidentifiedImageError

from app.schemas import ImageQualityResponse


MAX_PIXELS = 32_000_000
FAST_MAX_SIDE = 896
MIN_FEATURES_FOR_NEGATIVE = 160
MAX_MUTUAL_MATCHES_FOR_NEGATIVE = 1


def decode_rgb(content: bytes) -> Image.Image:
    if not content:
        raise ValueError("Uploaded image is empty.")
    try:
        with Image.open(BytesIO(content)) as image:
            if image.width * image.height > MAX_PIXELS:
                raise ValueError("Image dimensions are too large.")
            image.verify()
        with Image.open(BytesIO(content)) as image:
            return image.convert("RGB")
    except (UnidentifiedImageError, OSError) as exc:
        raise ValueError("Uploaded file is not a valid image.") from exc


def validate_close_image_without_model(content: bytes) -> ImageQualityResponse:
    """Exact production close-up quality rule, without loading any YOLO weights."""
    image = decode_rgb(content)
    gray = cv2.cvtColor(np.asarray(image), cv2.COLOR_RGB2GRAY)
    if float(gray.mean()) < 35.0:
        return ImageQualityResponse(
            suitable=False, code="TOO_DARK",
            message="Fotoğraf çok karanlık. Daha aydınlık bir ortamda tekrar çekin.",
        )
    if float(cv2.Laplacian(gray, cv2.CV_64F).var()) < 20.0:
        return ImageQualityResponse(
            suitable=False, code="TOO_BLURRY",
            message="Görüntü yeterince net değil. Kamerayı sabit tutup tekrar çekin.",
        )
    return ImageQualityResponse(
        suitable=True,
        code="SUITABLE",
        message="Yakın hasar fotoğrafı analiz için uygun.",
    )


def _compact_gray(image: Image.Image) -> np.ndarray:
    rgb = np.asarray(image)
    height, width = rgb.shape[:2]
    if max(height, width) > FAST_MAX_SIDE:
        ratio = FAST_MAX_SIDE / max(height, width)
        rgb = cv2.resize(
            rgb, (round(width * ratio), round(height * ratio)),
            interpolation=cv2.INTER_AREA,
        )
    return cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)


def _dhash(gray: np.ndarray) -> np.ndarray:
    small = cv2.resize(gray, (9, 8), interpolation=cv2.INTER_AREA)
    return (small[:, 1:] > small[:, :-1]).flatten()


def reject_obviously_unrelated_pair(
    close_bytes: bytes, context_bytes: bytes
) -> ImageQualityResponse | None:
    """Return a rejection only when cheap evidence is very strong.

    Missing evidence with low-texture or few detected features is inconclusive
    and MUST be delegated to existing YOLO-assisted pair verification.
    """
    if close_bytes == context_bytes:
        return ImageQualityResponse(
            suitable=False,
            code="DUPLICATE_IMAGE",
            message=(
                "Aynı fotoğraf iki kez yüklendi. Hasarı yakından ve "
                "aynı hasarı araç üzerinde daha geniş açıdan çekin."
            ),
        )

    close = _compact_gray(decode_rgb(close_bytes))
    context = _compact_gray(decode_rgb(context_bytes))
    # The same photo recompressed or scaled still must not count as two angles.
    if abs(close.shape[1] / close.shape[0] -
           context.shape[1] / context.shape[0]) < 0.015:
        hash_distance = int(np.count_nonzero(_dhash(close) != _dhash(context)))
        if hash_distance <= 1:
            return ImageQualityResponse(
                suitable=False, code="DUPLICATE_IMAGE",
                message="İki farklı açıdan fotoğraf yükleyin; görüntüler neredeyse aynı.",
            )

    # SIFT is scale invariant and runs on small CPU images. Low feature counts
    # cannot establish a mismatch, so those cases fall back to regular checks.
    detector = cv2.SIFT_create(nfeatures=900)
    close_keys, close_descriptors = detector.detectAndCompute(close, None)
    context_keys, context_descriptors = detector.detectAndCompute(context, None)
    if (
        close_descriptors is None or context_descriptors is None
        or len(close_keys) < MIN_FEATURES_FOR_NEGATIVE
        or len(context_keys) < MIN_FEATURES_FOR_NEGATIVE
    ):
        return None

    matcher = cv2.BFMatcher(cv2.NORM_L2)
    forward = matcher.knnMatch(close_descriptors, context_descriptors, k=2)
    backward = matcher.knnMatch(context_descriptors, close_descriptors, k=2)
    backwards = {
        pair[0].queryIdx: pair[0].trainIdx
        for pair in backward if len(pair) == 2
        and pair[0].distance < 0.72 * pair[1].distance
    }
    mutual_count = sum(
        1 for pair in forward
        if len(pair) == 2
        and pair[0].distance < 0.72 * pair[1].distance
        and backwards.get(pair[0].trainIdx) == pair[0].queryIdx
    )
    if mutual_count <= MAX_MUTUAL_MATCHES_FOR_NEGATIVE:
        return ImageQualityResponse(
            suitable=False,
            code="NO_SHARED_VISUAL_FEATURES",
            message=(
                "Fotoğraflar arasında yeterli ortak yüzey detayı bulunamadı. "
                "İki görüntüde aynı hasarlı bölgeyi ve çevresini gösterin."
            ),
        )
    return None
