import logging
from threading import BoundedSemaphore
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from .images import MAX_BYTES, ImageValidationError, prepare
from .provider import ProviderError, VisionUnavailable
from .schemas import AnalysisResponse
from .service import DamageAnalysisService

router = APIRouter()
runtime = DamageAnalysisService()
capacity = BoundedSemaphore(1)
logger = logging.getLogger(__name__)


def require_available():
    try:
        runtime.require_available()
    except VisionUnavailable as exc:
        raise HTTPException(503, {'code': 'DAMAGE_ANALYSIS_UNAVAILABLE', 'message': str(exc)}) from exc


@router.get('/api/v1/vision/readiness', dependencies=[Depends(require_available)])
def readiness():
    return {'status': 'READY', 'schemaVersion': 'gemini-vision-v1'}


async def read(image):
    if image.content_type not in ('image/jpeg', 'image/png', 'image/webp'):
        raise HTTPException(415, 'JPG, PNG veya WEBP kullanın.')
    content = await image.read(MAX_BYTES + 1)
    if len(content) > MAX_BYTES:
        raise HTTPException(413, 'Fotoğraf 10 MiB sınırını aşıyor.')
    return content


@router.post('/api/v1/analyze', response_model=AnalysisResponse, dependencies=[Depends(require_available)])
async def analyze(image: UploadFile = File(...), context_image: UploadFile = File(...),
                  vehicle_region: str | None = Form(None)):
    acquired = capacity.acquire(blocking=False)
    try:
        if not acquired:
            raise HTTPException(429, 'Analiz servisi meşgul; tekrar deneyin.')
        if vehicle_region not in (None, 'FRONT', 'REAR'):
            raise HTTPException(400, 'Araç bölgesi FRONT veya REAR olmalıdır.')
        return await run_in_threadpool(runtime.analyze, await read(image), await read(context_image),
                                       vehicle_region, image.content_type, context_image.content_type)
    except VisionUnavailable as exc:
        raise HTTPException(503, str(exc)) from exc
    except ProviderError as exc:
        raise HTTPException(502, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc
    finally:
        await image.close()
        await context_image.close()
        if acquired:
            capacity.release()


@router.post('/api/v1/validate-image')
async def validate(image: UploadFile = File(...)):
    # Local technical validation only. Content/blur/context are assessed together
    # in the one paid multimodal stage; this endpoint never calls Gemini.
    acquired = capacity.acquire(blocking=False)
    try:
        if not acquired:
            raise HTTPException(429, 'Görsel kontrol servisi meşgul; tekrar deneyin.')
        await run_in_threadpool(prepare, await read(image), image.content_type)
        return {'suitable': True, 'code': 'TECHNICALLY_VALID',
                'message': 'Dosya uygun; görsel yeterlilik iki fotoğraf birlikte değerlendirilirken kontrol edilecek.'}
    except ValueError as exc:
        code = exc.code if isinstance(exc, ImageValidationError) else 'INVALID_IMAGE'
        # Never log image bytes, metadata, filenames or request credentials.
        logger.warning('Image validation rejected code=%s', code)
        return {'suitable': False, 'code': code, 'message': str(exc)}
    finally:
        await image.close()
        if acquired:
            capacity.release()
