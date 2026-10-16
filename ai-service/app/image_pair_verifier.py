"""Conservative local correspondence check for close-up / context vehicle photos.

SIFT+RANSAC uses no new neural model. It provides evidence of the SAME
visible surface region, not biometric proof of vehicle identity. Missing
evidence is rejected rather than silently accepting unrelated pictures.
"""

import cv2
import numpy as np
from PIL import Image

from app.schemas import ImageQualityResponse


class ImagePairVerifier:
    MAX_SIDE = 1400
    MIN_INLIERS = 10
    MIN_INLIER_RATIO = 0.45
    MIN_DAMAGE_INLIERS = 3

    @staticmethod
    def _gray(image: Image.Image) -> np.ndarray:
        rgb = np.asarray(image.convert("RGB"))
        height, width = rgb.shape[:2]
        if max(height, width) > ImagePairVerifier.MAX_SIDE:
            scale = ImagePairVerifier.MAX_SIDE / max(height, width)
            rgb = cv2.resize(
                rgb, (round(width * scale), round(height * scale)),
                interpolation=cv2.INTER_AREA,
            )
        return cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)

    @staticmethod
    def _rejected(code: str) -> ImageQualityResponse:
        messages = {
            "INSUFFICIENT_VISUAL_OVERLAP": (
                "İki fotoğrafta aynı hasarlı araç yüzeyi doğrulanamadı. "
                "Geniş açı fotoğrafta yakın çekimdeki hasarı ve çevresindeki "
                "ayırt edici detayları da gösterin."
            ),
            "DAMAGE_REGION_UNVERIFIED": (
                "Yakın çekimdeki hasar bölgesinin geniş açı fotoğraftaki "
                "karşılığı doğrulanamadı. Aynı hasarı iki açıdan yeniden çekin."
            ),
        }
        return ImageQualityResponse(
            suitable=False, code=code, message=messages[code]
        )

    def verify(
        self,
        close_image: Image.Image,
        vehicle_crop: Image.Image,
        damage_boxes: list[tuple[float, float, float, float]] | None = None,
    ) -> ImageQualityResponse:
        close_gray = self._gray(close_image)
        context_gray = self._gray(vehicle_crop)
        detector = cv2.SIFT_create(nfeatures=1400)
        close_points, close_descriptors = detector.detectAndCompute(close_gray, None)
        context_points, context_descriptors = detector.detectAndCompute(context_gray, None)
        if (
            close_descriptors is None or context_descriptors is None
            or len(close_points) < self.MIN_INLIERS
            or len(context_points) < self.MIN_INLIERS
        ):
            return self._rejected("INSUFFICIENT_VISUAL_OVERLAP")

        matcher = cv2.BFMatcher(cv2.NORM_L2, crossCheck=False)
        forward = matcher.knnMatch(close_descriptors, context_descriptors, k=2)
        reverse = matcher.knnMatch(context_descriptors, close_descriptors, k=2)
        reverse_best = {
            pair[0].queryIdx: pair[0].trainIdx
            for pair in reverse
            if len(pair) == 2 and pair[0].distance < 0.76 * pair[1].distance
        }
        matches = [
            pair[0] for pair in forward
            if len(pair) == 2
            and pair[0].distance < 0.76 * pair[1].distance
            and reverse_best.get(pair[0].trainIdx) == pair[0].queryIdx
        ]
        if len(matches) < self.MIN_INLIERS:
            return self._rejected("INSUFFICIENT_VISUAL_OVERLAP")

        source = np.float32([close_points[m.queryIdx].pt for m in matches])
        target = np.float32([context_points[m.trainIdx].pt for m in matches])
        transform, mask = cv2.findHomography(
            source.reshape(-1, 1, 2), target.reshape(-1, 1, 2),
            cv2.RANSAC, 4.0,
        )
        if transform is None or mask is None or not np.isfinite(transform).all():
            return self._rejected("INSUFFICIENT_VISUAL_OVERLAP")

        accepted = mask.ravel() != 0
        inliers = source[accepted]
        if len(inliers) < self.MIN_INLIERS or len(inliers) / len(matches) < self.MIN_INLIER_RATIO:
            return self._rejected("INSUFFICIENT_VISUAL_OVERLAP")

        # A repeated logo/texture occupying only a tiny patch is not proof
        # that the photographs show the same surrounding body surface.
        h, w = close_gray.shape
        spans = np.ptp(inliers, axis=0)
        hull = cv2.convexHull(inliers.reshape(-1, 1, 2))
        area_fraction = cv2.contourArea(hull) / max(1, w * h)
        if spans[0] < 0.12 * w or spans[1] < 0.08 * h or area_fraction < 0.008:
            return self._rejected("INSUFFICIENT_VISUAL_OVERLAP")

        # The matched keypoints must also support the actual damage location,
        # not just some unrelated detail in the close-up photograph.
        if damage_boxes:
            original_w, original_h = close_image.size
            scale_x = w / original_w
            scale_y = h / original_h
            supported = False
            for x1, y1, x2, y2 in damage_boxes:
                x1, x2 = x1 * scale_x, x2 * scale_x
                y1, y2 = y1 * scale_y, y2 * scale_y
                margin_x = max((x2 - x1) * 0.65, w * 0.04)
                margin_y = max((y2 - y1) * 0.65, h * 0.04)
                nearby = (
                    (inliers[:, 0] >= x1 - margin_x)
                    & (inliers[:, 0] <= x2 + margin_x)
                    & (inliers[:, 1] >= y1 - margin_y)
                    & (inliers[:, 1] <= y2 + margin_y)
                )
                if int(nearby.sum()) < self.MIN_DAMAGE_INLIERS:
                    continue
                center = np.array([[[0.5 * (x1 + x2), 0.5 * (y1 + y2)]]], dtype=np.float32)
                mapped = cv2.perspectiveTransform(center, transform)[0, 0]
                context_h, context_w = context_gray.shape
                if (
                    np.isfinite(mapped).all()
                    and 0 <= mapped[0] < context_w
                    and 0 <= mapped[1] < context_h
                ):
                    supported = True
                    break
            if not supported:
                return self._rejected("DAMAGE_REGION_UNVERIFIED")

        return ImageQualityResponse(
            suitable=True,
            code="PAIR_REGION_MATCHED",
            message="İki fotoğraftaki araç yüzeyi ve hasar çevresi görsel olarak eşleşiyor.",
        )
