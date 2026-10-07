from dataclasses import dataclass
from .retriever import SemanticRetriever
from .routing import DeterministicDomainRouter, RouteDecision
from .schemas import RetrievedChunk


@dataclass(frozen=True)
class AssistantPlan:
    decision: RouteDecision
    retrieved_chunks: tuple[RetrievedChunk, ...] = ()


class AssistantOrchestrator:
    """Plans an assistant turn before any expensive LLM generation happens."""

    def __init__(self, router: DeterministicDomainRouter,
                 retriever: SemanticRetriever | None = None) -> None:
        self.router = router
        self.retriever = retriever

    def plan(self, question: str) -> AssistantPlan:
        decision = self.router.route(question)
        if not decision.in_scope:
            return AssistantPlan(decision)
        if decision.use_rag and self.retriever is not None:
            return AssistantPlan(decision, tuple(self.retriever.retrieve(question)))
        return AssistantPlan(decision)
