import hashlib
from dataclasses import dataclass
from pathlib import Path

from .chunking import HybridSemanticChunker
from .embeddings import LocalMultilingualEmbedder
from .schemas import KnowledgeDocument
from .vector_store import PgVectorKnowledgeStore


@dataclass(frozen=True)
class KnowledgeSource:
    path: Path
    category: str
    source_name: str
    source_version: str
    source_url: str | None = None
    authority: str = "CURATED"
    language: str = "tr"
    market: str | None = "TR"


@dataclass(frozen=True)
class IngestionResult:
    slug: str
    status: str
    chunks: int


class KnowledgeIngestionService:
    def __init__(self, store: PgVectorKnowledgeStore,
                 embedder: LocalMultilingualEmbedder,
                 chunker: HybridSemanticChunker) -> None:
        self.store = store
        self.embedder = embedder
        self.chunker = chunker

    def ingest(self, source: KnowledgeSource) -> IngestionResult:
        content = source.path.read_text(encoding="utf-8").strip()
        if not content:
            return IngestionResult(source.path.stem, "EMPTY", 0)

        slug = source.path.stem.replace("_", "-").lower()
        digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
        current = self.store.find_active_document(slug)
        if current and current.content_hash == digest:
            return IngestionResult(slug, "UNCHANGED", 0)

        title = next(
            (line.lstrip("# ").strip() for line in content.splitlines()
             if line.startswith("#")),
            source.path.stem.replace("_", " ").title(),
        )
        document = KnowledgeDocument(
            slug=slug, title=title, category=source.category, content=content,
            source_name=source.source_name, source_url=source.source_url,
            source_version=source.source_version,
        )
        chunks = self.chunker.chunk(document)
        embeddings = self.embedder.embed_passages([chunk.content for chunk in chunks])
        document_id = self.store.publish_document(
            slug=slug, title=title, category=source.category,
            content_hash=digest, source_name=source.source_name,
            source_url=source.source_url, source_version=source.source_version,
            authority=source.authority, language=source.language, market=source.market,
        )
        self.store.replace_chunks(document_id, chunks, embeddings)
        return IngestionResult(slug, "UPDATED" if current else "CREATED", len(chunks))
