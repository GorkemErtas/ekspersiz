from pydantic import BaseModel, Field

class AssistantPlanRequest(BaseModel):
    question: str = Field(min_length=1, max_length=2000)

class RetrievedContext(BaseModel):
    title: str
    category: str
    content: str
    similarity: float

class AssistantPlanResponse(BaseModel):
    intent: str
    in_scope: bool
    use_rag: bool
    tool_name: str | None = None
    reason: str
    automotive_relevance: float = 0.0
    assistant_capability: float = 0.0
    context: list[RetrievedContext] = Field(default_factory=list)
