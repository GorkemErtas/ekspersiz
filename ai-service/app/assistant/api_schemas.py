from pydantic import BaseModel, Field

class AssistantHistoryMessage(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=2000)

class AssistantVehicleContext(BaseModel):
    brand: str = Field(min_length=1, max_length=100)
    model: str = Field(min_length=1, max_length=100)
    modelYear: int = Field(ge=1886, le=2100)

class AssistantPlanRequest(BaseModel):
    question: str = Field(min_length=1, max_length=2000)
    history: list[AssistantHistoryMessage] = Field(default_factory=list, max_length=6)
    vehicle_context: AssistantVehicleContext | None = None

class RetrievedContext(BaseModel):
    title: str
    category: str
    content: str
    similarity: float
    source_name: str | None = None
    source_url: str | None = None

class AssistantPlanResponse(BaseModel):
    intent: str
    in_scope: bool
    use_rag: bool
    tool_name: str | None = None
    reason: str
    automotive_relevance: float = 0.0
    assistant_capability: float = 0.0
    evidence_score: float = 0.0
    evidence_sufficient: bool = True
    clarification_needed: bool = False
    clarification_message: str | None = None
    context: list[RetrievedContext] = Field(default_factory=list)
