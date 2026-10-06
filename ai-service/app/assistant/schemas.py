from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class KnowledgeDocument:
    slug: str
    title: str
    category: str
    content: str
    source_name: str | None = None
    source_url: str | None = None
    source_version: str | None = None


@dataclass(frozen=True)
class KnowledgeChunk:
    document_slug: str
    chunk_index: int
    content: str
    heading: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class RetrievedChunk:
    chunk_id: int
    document_slug: str
    title: str
    category: str
    content: str
    similarity: float
    market: str | None = None
    authority: str | None = None
    source_version: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)
