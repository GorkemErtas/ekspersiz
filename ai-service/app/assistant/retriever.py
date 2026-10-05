from .embeddings import LocalMultilingualEmbedder
from .schemas import RetrievedChunk
from .vector_store import PgVectorKnowledgeStore


class SemanticRetriever:
    def __init__(self, embedder: LocalMultilingualEmbedder,
                 store: PgVectorKnowledgeStore) -> None:
        self.embedder = embedder
        self.store = store

    def retrieve(self, question: str, *, candidate_k: int = 8,
                 final_k: int = 4, min_similarity: float = 0.55) -> list[RetrievedChunk]:
        question = question.strip()
        if not question:
            return []
        vector = self.embedder.embed_query(question)
        candidates = self.store.search(
            vector, limit=candidate_k, min_similarity=min_similarity
        )
        return candidates[:final_k]
