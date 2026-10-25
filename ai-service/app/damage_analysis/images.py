"""Bounded, format-aware decoding; no learned model and no image persistence."""
from dataclasses import dataclass
import hashlib
import io
import warnings
from PIL import Image, ImageOps, ImageStat, UnidentifiedImageError

MAX_BYTES = 10 * 1024 * 1024
MAX_PIXELS = 24_000_000
FORMATS = {'JPEG': 'image/jpeg', 'PNG': 'image/png', 'WEBP': 'image/webp'}


@dataclass(frozen=True)
class PreparedImage:
    jpeg: bytes
    fingerprint: str


def prepare(content: bytes, declared_type: str | None = None) -> PreparedImage:
    if not content or len(content) > MAX_BYTES:
        raise ValueError('Her fotoğraf dolu ve en fazla 10 MiB olmalıdır.')
    try:
        with warnings.catch_warnings():
            warnings.simplefilter('error', Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(content)) as source:
                if source.format not in FORMATS or (declared_type and FORMATS[source.format] != declared_type):
                    raise ValueError('Dosya içeriği JPG, PNG veya WEBP biçimiyle eşleşmelidir.')
                if getattr(source, 'is_animated', False):
                    raise ValueError('Hareketli görsel yerine tek bir fotoğraf yükleyin.')
                if source.width * source.height > MAX_PIXELS or min(source.size) < 256:
                    raise ValueError('Fotoğrafın kısa kenarı en az 256 piksel, toplamı en fazla 24 MP olmalıdır.')
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
                    raise ValueError('Fotoğraf yeterli görsel ayrıntı içermiyor; net ve aydınlık bir fotoğraf çekin.')
                image.thumbnail((2048, 2048), Image.Resampling.LANCZOS)
                result = io.BytesIO()
                # Re-encoding removes EXIF/GPS, filenames and ancillary metadata.
                image.save(result, format='JPEG', quality=85)
                return PreparedImage(result.getvalue(), fingerprint)
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
        raise ValueError('Fotoğraf okunamadı veya güvenli çözünürlük sınırını aşıyor.') from exc
