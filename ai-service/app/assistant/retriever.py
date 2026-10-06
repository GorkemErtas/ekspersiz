from .embeddings import LocalMultilingualEmbedder
from .schemas import RetrievedChunk
from .settings import AssistantSettings
from .vector_store import PgVectorKnowledgeStore


class SemanticRetriever:
    def __init__(self, embedder: LocalMultilingualEmbedder,
                 store: PgVectorKnowledgeStore,
                 settings: AssistantSettings | None = None) -> None:
        self.embedder = embedder
        self.store = store
        self.settings = settings or AssistantSettings.from_env()

    def retrieve(self, question: str, *, candidate_k: int | None = None,
                 final_k: int | None = None,
                 min_similarity: float | None = None) -> list[RetrievedChunk]:
        question = question.strip()
        if not question:
            return []

        candidate_k = candidate_k or self.settings.retrieval_candidate_k
        final_k = final_k or self.settings.retrieval_final_k
        min_similarity = (
            self.settings.retrieval_min_similarity
            if min_similarity is None else min_similarity
        )
        if not 1 <= final_k <= candidate_k <= 20:
            raise ValueError("invalid retrieval top-k")
        if not 0.0 <= min_similarity <= 1.0:
            raise ValueError("invalid retrieval similarity threshold")

        vector = self.embedder.embed_query(question)
        candidates = self.store.search(
            vector, limit=candidate_k, min_similarity=min_similarity
        )
        return candidates[:final_k]
