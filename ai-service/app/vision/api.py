from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool

from .runtime import UnifiedVisionRuntime, VisionUnavailable
from .schemas import UnifiedAnalysisResponse
from threading import BoundedSemaphore

router=APIRouter()
runtime=UnifiedVisionRuntime()
MAX_BYTES=10*1024*1024
capacity=BoundedSemaphore(2)


def require_available():
    try:
        runtime.require_available()
    except VisionUnavailable as exc:
        raise HTTPException(503,{'code':'DAMAGE_ANALYSIS_UNAVAILABLE','message':str(exc)}) from exc


@router.get('/api/v1/vision/readiness')
def readiness():
    require_available()
    return {'status':'READY','schemaVersion':'hitl-v1'}


async def read(image):
    if image.content_type not in ('image/jpeg','image/png','image/webp'):
        raise HTTPException(415,'JPG, PNG veya WEBP kullanın.')
    content=await image.read(MAX_BYTES+1)
    if len(content)>MAX_BYTES:
        raise HTTPException(413,'Fotoğraf 10 MiB sınırını aşıyor.')
    if not content:
        raise HTTPException(400,'Fotoğraf boş olamaz.')
    return content


async def analyze(image: UploadFile=File(...),vehicle_region: str|None=Form(None)):
    acquired=capacity.acquire(blocking=False)
    try:
        if not acquired:
            raise HTTPException(429,'Analiz servisi meşgul; tekrar deneyin.')
        if vehicle_region not in (None,'FRONT','REAR'):
            raise HTTPException(400,'Araç bölgesi FRONT veya REAR olmalıdır.')
        content=await read(image)
        return await run_in_threadpool(runtime.analyze,content,vehicle_region)
    except VisionUnavailable as exc:
        raise HTTPException(503,'Doğrulanmış hasar modeli hazır değil.') from exc
    except ValueError as exc:
        raise HTTPException(400,str(exc)) from exc
    finally:
        await image.close()
        if acquired:
            capacity.release()


async def validate(image: UploadFile=File(...)):
    acquired=capacity.acquire(blocking=False)
    try:
        if not acquired:
            raise HTTPException(429,'Analiz servisi meşgul; tekrar deneyin.')
        return await run_in_threadpool(runtime.validate,await read(image))
    except VisionUnavailable as exc:
        raise HTTPException(503,'Doğrulanmış hasar modeli hazır değil.') from exc
    except ValueError as exc:
        raise HTTPException(400,str(exc)) from exc
    finally:
        await image.close()
        if acquired:
            capacity.release()


# Route dependencies run before any image work. Middleware additionally rejects
# disabled image endpoints before FastAPI attempts multipart parsing.
from fastapi import Depends
router.add_api_route('/api/v1/analyze',analyze,methods=['POST'],response_model=UnifiedAnalysisResponse,dependencies=[Depends(require_available)])
router.add_api_route('/api/v1/validate-image',validate,methods=['POST'],dependencies=[Depends(require_available)])
