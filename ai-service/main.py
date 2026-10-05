import logging
import os

from fastapi import (
    FastAPI,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
)

from app.damage_analyzer import DamageAnalyzer
from app.schemas import DamageAnalysisResponse, ImageQualityResponse
from app.assistant.api_schemas import AssistantPlanRequest, AssistantPlanResponse, RetrievedContext
from app.assistant.routing import DeterministicDomainRouter
from app.assistant.embeddings import LocalMultilingualEmbedder
from app.assistant.vector_store import PgVectorKnowledgeStore
from app.assistant.retriever import SemanticRetriever


logger = logging.getLogger(__name__)


app = FastAPI(
    title="Vehicle Damage Analysis API",
    version="1.4.0",
)

damage_analyzer = DamageAnalyzer()

ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
}

MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024


async def read_valid_image(image: UploadFile) -> bytes:
    if image.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail="Only JPG, PNG and WEBP images are supported.",
        )

    file_content = await image.read()
    if not file_content:
        raise HTTPException(status_code=400, detail="Uploaded image cannot be empty.")
    if len(file_content) > MAX_IMAGE_SIZE_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Uploaded image cannot be larger than 10 MB.",
        )
    return file_content


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
        context_image: UploadFile | None = File(default=None),
        vehicle_region: str | None = Form(default=None),
) -> DamageAnalysisResponse:
    try:
        file_content = await read_valid_image(image)

        if context_image is None:
            return damage_analyzer.analyze(
                file_content=file_content,
                filename=image.filename or "vehicle.jpg",
            )

        context_file_content = await read_valid_image(context_image)
        normalized_region = (
            vehicle_region.upper()
            if vehicle_region is not None
            else None
        )
        if normalized_region not in {None, "FRONT", "REAR"}:
            raise HTTPException(
                status_code=400,
                detail="vehicle_region must be FRONT or REAR.",
            )

        return damage_analyzer.analyze_pair(
            damage_file_content=file_content,
            context_file_content=context_file_content,
            filename=image.filename or "vehicle.jpg",
            vehicle_region=normalized_region,
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
        if context_image is not None:
            await context_image.close()


@app.post(
    "/api/v1/validate-image",
    response_model=ImageQualityResponse,
)
async def validate_image_quality(
        image: UploadFile = File(...),
        purpose: str = Query(
            default="context",
            pattern="^(damage|context)$",
        ),
) -> ImageQualityResponse:
    try:
        file_content = await read_valid_image(image)
        return damage_analyzer.validate_image_quality(
            file_content,
            purpose=purpose,
        )
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Unexpected error during image quality validation.")
        raise HTTPException(
            status_code=500,
            detail="Image quality could not be validated.",
        ) from exc
    finally:
        await image.close()


assistant_router = DeterministicDomainRouter()
_assistant_retriever = None


def get_assistant_retriever():
    global _assistant_retriever
    if _assistant_retriever is None:
        database_url = os.getenv("DATABASE_URL")
        if not database_url:
            raise RuntimeError("DATABASE_URL is required for assistant RAG retrieval")
        _assistant_retriever = SemanticRetriever(LocalMultilingualEmbedder(), PgVectorKnowledgeStore(database_url))
    return _assistant_retriever


@app.post("/api/v1/assistant/plan", response_model=AssistantPlanResponse)
def plan_assistant_turn(request: AssistantPlanRequest) -> AssistantPlanResponse:
    decision = assistant_router.route(request.question)
    context = []
    if decision.in_scope and decision.use_rag:
        chunks = get_assistant_retriever().retrieve(request.question)
        context = [RetrievedContext(title=x.title, category=x.category, content=x.content, similarity=x.similarity) for x in chunks]
    return AssistantPlanResponse(
        intent=decision.intent.value,
        in_scope=decision.in_scope,
        use_rag=decision.use_rag,
        tool_name=decision.tool_name,
        reason=decision.reason,
        context=context,
    )
