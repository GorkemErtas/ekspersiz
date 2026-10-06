import os
from dataclasses import dataclass


def _int(name: str, default: int) -> int:
    return int(os.getenv(name, str(default)))


def _float(name: str, default: float) -> float:
    return float(os.getenv(name, str(default)))


@dataclass(frozen=True)
class AssistantSettings:
    chunk_target_tokens: int = 420
    chunk_min_tokens: int = 120
    chunk_max_tokens: int = 560
    chunk_similarity_threshold: float = 0.72
    retrieval_candidate_k: int = 8
    retrieval_final_k: int = 4
    retrieval_min_similarity: float = 0.55

    @classmethod
    def from_env(cls) -> "AssistantSettings":
        settings = cls(
            chunk_target_tokens=_int("ASSISTANT_CHUNK_TARGET_TOKENS", 420),
            chunk_min_tokens=_int("ASSISTANT_CHUNK_MIN_TOKENS", 120),
            chunk_max_tokens=_int("ASSISTANT_CHUNK_MAX_TOKENS", 560),
            chunk_similarity_threshold=_float(
                "ASSISTANT_CHUNK_SIMILARITY_THRESHOLD", 0.72),
            retrieval_candidate_k=_int("ASSISTANT_RETRIEVAL_CANDIDATE_K", 8),
            retrieval_final_k=_int("ASSISTANT_RETRIEVAL_FINAL_K", 4),
            retrieval_min_similarity=_float(
                "ASSISTANT_RETRIEVAL_MIN_SIMILARITY", 0.55),
        )
        settings.validate()
        return settings

    def validate(self) -> None:
        if not 50 <= self.chunk_min_tokens <= self.chunk_target_tokens <= self.chunk_max_tokens:
            raise ValueError("invalid assistant chunk token configuration")
        if not 0.0 < self.chunk_similarity_threshold < 1.0:
            raise ValueError("invalid assistant chunk similarity threshold")
        if not 1 <= self.retrieval_final_k <= self.retrieval_candidate_k <= 20:
            raise ValueError("invalid assistant retrieval top-k configuration")
        if not 0.0 <= self.retrieval_min_similarity <= 1.0:
            raise ValueError("invalid assistant retrieval similarity threshold")
