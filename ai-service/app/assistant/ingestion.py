import hashlib
from dataclasses import dataclass
from pathlib import Path

from .chunking import HybridSemanticChunker
from .embeddings import LocalMultilingualEmbedder
from .document_parser import DocumentParserRegistry
from .schemas import KnowledgeDocument
from .vector_store import KnowledgeVersionConflict, PgVectorKnowledgeStore


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
                 chunker: HybridSemanticChunker,
                 parsers: DocumentParserRegistry | None = None) -> None:
        self.store = store
        self.embedder = embedder
        self.chunker = chunker
        self.parsers = parsers or DocumentParserRegistry()

    def ingest(self, source: KnowledgeSource) -> IngestionResult:
        parsed = self.parsers.parse(source.path)
        content = parsed.content.strip()
        if not content:
            return IngestionResult(source.path.stem, "EMPTY", 0)

        slug = source.path.stem.replace("_", "-").lower()
        digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
        current = self.store.find_active_document(slug)
        if current and current.content_hash == digest:
            return IngestionResult(slug, "UNCHANGED", 0)

        existing_version = self.store.find_version(slug, source.source_version)
        if existing_version:
            if existing_version.content_hash == digest:
                return IngestionResult(slug, "UNCHANGED", 0)
            raise KnowledgeVersionConflict(
                f"{slug} source_version={source.source_version} already exists with different content; publish a new version"
            )

        title = parsed.title
        document = KnowledgeDocument(
            slug=slug, title=title, category=source.category, content=content,
            source_name=source.source_name, source_url=source.source_url,
            source_version=source.source_version,
        )
        chunks = self.chunker.chunk(document)
        embeddings = self.embedder.embed_passages([chunk.content for chunk in chunks])
        self.store.publish_version(
            slug=slug, title=title, category=source.category,
            content_hash=digest, source_name=source.source_name,
            source_url=source.source_url, source_version=source.source_version,
            chunks=chunks, embeddings=embeddings,
            authority=source.authority, language=source.language, market=source.market,
        )
        return IngestionResult(slug, "UPDATED" if current else "CREATED", len(chunks))
