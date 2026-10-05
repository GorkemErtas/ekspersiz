from collections.abc import Sequence


class LocalMultilingualEmbedder:
    """Lazy local sentence-transformer adapter; no per-request embedding API cost."""

    DEFAULT_MODEL = "intfloat/multilingual-e5-small"
    DIMENSION = 384

    def __init__(self, model_name: str = DEFAULT_MODEL) -> None:
        self.model_name = model_name
        self._model = None

    def _load(self):
        if self._model is None:
            try:
                from sentence_transformers import SentenceTransformer
            except ImportError as exc:
                raise RuntimeError(
                    "sentence-transformers is required for AI Assistant embeddings"
                ) from exc
            self._model = SentenceTransformer(self.model_name)
        return self._model

    def embed_passages(self, texts: Sequence[str]) -> list[list[float]]:
        prepared = [f"passage: {text.strip()}" for text in texts]
        return self._encode(prepared)

    def embed_query(self, text: str) -> list[float]:
        return self._encode([f"query: {text.strip()}"])[0]

    def _encode(self, texts: Sequence[str]) -> list[list[float]]:
        if not texts:
            return []
        vectors = self._load().encode(
            list(texts),
            normalize_embeddings=True,
            show_progress_bar=False,
        )
        result = vectors.tolist()
        if result and len(result[0]) != self.DIMENSION:
            raise RuntimeError(
                f"Unexpected embedding dimension: {len(result[0])}; expected {self.DIMENSION}"
            )
        return result
