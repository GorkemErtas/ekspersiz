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
from app.assistant.domain_classifier import SemanticDomainClassifier
from app.assistant.embeddings import LocalMultilingualEmbedder
from app.assistant.vector_store import PgVectorKnowledgeStore
from app.assistant.retriever import SemanticRetriever
from app.assistant.settings import AssistantSettings
from app.assistant.spec_evidence import VehicleSpecIdentity, validate_vehicle_spec_evidence


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


assistant_router = SemanticDomainClassifier()
_assistant_retriever = None


def get_assistant_retriever():
    global _assistant_retriever
    if _assistant_retriever is None:
        database_url = os.getenv("DATABASE_URL")
        if not database_url:
            raise RuntimeError("DATABASE_URL is required for assistant RAG retrieval")
        _assistant_retriever = SemanticRetriever(LocalMultilingualEmbedder(), PgVectorKnowledgeStore(database_url), AssistantSettings.from_env())
    return _assistant_retriever


@app.get("/api/v1/assistant/readiness")
def assistant_readiness():
    try:
        database_url = os.getenv("DATABASE_URL")
        if not database_url:
            raise RuntimeError("DATABASE_URL is not configured")
        store = PgVectorKnowledgeStore(database_url)
        storage = store.readiness()
        ready = (
            bool(storage["pgvector"])
            and int(storage["active_documents"]) > 0
            and int(storage["active_chunks"]) > 0
            and int(storage["embedding_dimensions"]) == 384
        )
        return {"status": "READY" if ready else "NOT_READY", **storage}
    except Exception:
        logger.exception("Assistant readiness check failed.")
        raise HTTPException(status_code=503, detail="Assistant RAG is not ready.")


@app.post("/api/v1/assistant/plan", response_model=AssistantPlanResponse)
def plan_assistant_turn(request: AssistantPlanRequest) -> AssistantPlanResponse:
    context_lines = []
    for item in request.history:
        context_lines.append(f"{item.role.upper()}: {item.content}")
    if request.vehicle_context is not None:
        vehicle = request.vehicle_context
        context_lines.append(
            f"SELECTED_VEHICLE: {vehicle.brand} {vehicle.model}, model year {vehicle.modelYear}"
        )
    conversation_context = "\n".join(context_lines)
    decision = assistant_router.route(
        request.question, conversation_context=conversation_context
    )
    context = []
    evidence_score = 0.0
    evidence_sufficient = True
    clarification_needed = decision.clarification_needed
    clarification_message = decision.clarification_message

    if decision.in_scope and decision.intent.value == "VEHICLE_SPEC":
        has_selected_vehicle = request.vehicle_context is not None
        missing = []
        if not has_selected_vehicle:
            if decision.vehicle_year is None:
                missing.append("model yılı")
            if not decision.vehicle_make:
                missing.append("marka")
            if not decision.vehicle_model:
                missing.append("model")
        if missing:
            clarification_needed = True
            clarification_message = (
                "Bunu doğru yanıtlayabilmem için " + ", ".join(missing)
                + " bilgisini de paylaşır mısınız?"
            )

    if decision.in_scope and decision.use_rag and not clarification_needed:
        retrieval_query = (
            request.question + "\n" + conversation_context
            if conversation_context else request.question
        )
        chunks = get_assistant_retriever().retrieve(retrieval_query)
        context = [RetrievedContext(title=x.title, category=x.category, content=x.content, similarity=x.similarity, source_name=x.source_name, source_url=x.source_url) for x in chunks]
        evidence_score = max((x.similarity for x in chunks), default=0.0)
        settings = AssistantSettings.from_env()
        threshold = settings.evidence_min_similarity
        evidence_sufficient = evidence_score >= threshold
        if decision.intent.value == "VEHICLE_SPEC":
            spec_result = validate_vehicle_spec_evidence(
                VehicleSpecIdentity(
                    year=decision.vehicle_year,
                    make=decision.vehicle_make,
                    model=decision.vehicle_model,
                    trim=decision.vehicle_trim,
                    market=decision.vehicle_market,
                ),
                chunks,
                settings.vehicle_spec_min_similarity,
            )
            evidence_score = spec_result.score
            evidence_sufficient = spec_result.sufficient
    return AssistantPlanResponse(
        intent=decision.intent.value,
        in_scope=decision.in_scope,
        use_rag=decision.use_rag,
        knowledge_source=decision.knowledge_source,
        tool_name=decision.tool_name,
        reason=decision.reason,
        automotive_relevance=decision.automotive_relevance,
        assistant_capability=decision.assistant_capability,
        evidence_score=evidence_score,
        evidence_sufficient=evidence_sufficient,
        clarification_needed=clarification_needed,
        clarification_message=clarification_message,
        context=context,
    )
