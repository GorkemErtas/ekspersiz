"""Bounded, format-aware decoding; no learned model and no image persistence."""
from dataclasses import dataclass
import hashlib
import io
import warnings
from PIL import Image, ImageOps, ImageStat, UnidentifiedImageError

MAX_BYTES = 10 * 1024 * 1024
MAX_PIXELS = 24_000_000
FORMATS = {'JPEG': 'image/jpeg', 'PNG': 'image/png', 'WEBP': 'image/webp'}


class ImageValidationError(ValueError):
    """Stable, non-sensitive rejection reason shared by validation and analysis."""
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class PreparedImage:
    jpeg: bytes
    fingerprint: str


def prepare(content: bytes, declared_type: str | None = None) -> PreparedImage:
    if not content or len(content) > MAX_BYTES:
        raise ImageValidationError('IMAGE_SIZE_INVALID', 'Her fotoğraf dolu ve en fazla 10 MiB olmalıdır.')
    try:
        with warnings.catch_warnings():
            warnings.simplefilter('error', Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(content)) as source:
                if source.format not in FORMATS or (declared_type and FORMATS[source.format] != declared_type):
                    raise ImageValidationError('IMAGE_FORMAT_INVALID', 'Dosya içeriği JPG, PNG veya WEBP biçimiyle eşleşmelidir.')
                if getattr(source, 'is_animated', False):
                    raise ImageValidationError('IMAGE_ANIMATED', 'Hareketli görsel yerine tek bir fotoğraf yükleyin.')
                if source.width * source.height > MAX_PIXELS:
                    raise ImageValidationError('IMAGE_RESOLUTION_EXCEEDED', 'Fotoğraf 24 MP sınırını aşıyor. Uygulamayı güncelleyip fotoğrafı yeniden seçerek yükleyin.')
                if min(source.size) < 256:
                    raise ImageValidationError('IMAGE_RESOLUTION_TOO_LOW', 'Fotoğrafın kısa kenarı en az 256 piksel olmalıdır.')
                source.verify()
            with Image.open(io.BytesIO(content)) as source:
                ImageOps.exif_transpose(source, in_place=True)
                image = source.convert('RGB')
                digest = hashlib.sha256(str(image.size).encode())
                digest.update(image.tobytes())
                fingerprint = digest.hexdigest()
                gray = image.copy()
                gray.thumbnail((256, 256))
                if ImageStat.Stat(gray.convert('L')).stddev[0] < 2:
                    raise ImageValidationError('IMAGE_DETAIL_INSUFFICIENT', 'Fotoğraf yeterli görsel ayrıntı içermiyor; net ve aydınlık bir fotoğraf çekin.')
                image.thumbnail((2048, 2048), Image.Resampling.LANCZOS)
                result = io.BytesIO()
                # Re-encoding removes EXIF/GPS, filenames and ancillary metadata.
                image.save(result, format='JPEG', quality=85)
                return PreparedImage(result.getvalue(), fingerprint)
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
        raise ImageValidationError('IMAGE_DECODE_FAILED', 'Fotoğraf okunamadı veya güvenli çözünürlük sınırını aşıyor.') from exc
