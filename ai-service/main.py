import logging

from fastapi import (
    FastAPI,
    File,
    HTTPException,
    UploadFile,
)

from app.damage_analyzer import DamageAnalyzer
from app.schemas import DamageAnalysisResponse


logger = logging.getLogger(__name__)


app = FastAPI(
    title="Vehicle Damage Analysis API",
    version="1.3.0",
)

damage_analyzer = DamageAnalyzer()

ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
}

MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024


@app.get("/health")
def health_check():
    return {
        "status": "UP",
        "service": "vehicle-damage-ai",
        "version": app.version,
    }


@app.post(
    "/api/v1/analyze",
    response_model=DamageAnalysisResponse,
)
async def analyze_damage(
        image: UploadFile = File(...),
) -> DamageAnalysisResponse:
    try:
        if image.content_type not in ALLOWED_CONTENT_TYPES:
            raise HTTPException(
                status_code=415,
                detail=(
                    "Only JPG, PNG and WEBP images "
                    "are supported."
                ),
            )

        file_content = await image.read()

        if not file_content:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Uploaded image cannot be empty."
                ),
            )

        if (
                len(file_content)
                > MAX_IMAGE_SIZE_BYTES
        ):
            raise HTTPException(
                status_code=413,
                detail=(
                    "Uploaded image cannot be larger "
                    "than 10 MB."
                ),
            )

        return damage_analyzer.analyze(
            file_content=file_content,
            filename=image.filename or "vehicle.jpg",
        )

    except HTTPException:
        raise

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    except Exception as exc:
        logger.exception(
            "Unexpected error during AI analysis."
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "AI analysis could not be completed."
            ),
        ) from exc

    finally:
        await image.close()