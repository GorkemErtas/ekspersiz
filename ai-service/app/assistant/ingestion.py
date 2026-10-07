import hashlib
from dataclasses import dataclass
from datetime import date
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
    slug: str | None = None
    source_url: str | None = None
    authority: str = "CURATED"
    language: str = "tr"
    market: str | None = "TR"
    valid_from: date | None = None
    valid_until: date | None = None
    vehicle_years: tuple[int, ...] = ()
    vehicle_makes: tuple[str, ...] = ()
    vehicle_models: tuple[str, ...] = ()
    vehicle_trims: tuple[str, ...] = ()
    applies_all_trims: bool = False


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

        slug = source.slug or source.path.stem.replace("_", "-").lower()
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
            metadata={
                "vehicle_years": list(source.vehicle_years),
                "vehicle_makes": list(source.vehicle_makes),
                "vehicle_models": list(source.vehicle_models),
                "vehicle_trims": list(source.vehicle_trims),
                "applies_all_trims": source.applies_all_trims,
                "market": source.market,
                "authority": source.authority,
            },
        )
        chunks = self.chunker.chunk(document)
        embeddings = self.embedder.embed_passages([chunk.content for chunk in chunks])
        self.store.publish_version(
            slug=slug, title=title, category=source.category,
            content_hash=digest, source_name=source.source_name,
            source_url=source.source_url, source_version=source.source_version,
            chunks=chunks, embeddings=embeddings,
            authority=source.authority, language=source.language, market=source.market,
            valid_from=source.valid_from, valid_until=source.valid_until,
        )
        return IngestionResult(slug, "UPDATED" if current else "CREATED", len(chunks))
