import argparse
import os
import sys
from pathlib import Path

AI_SERVICE_ROOT = Path(__file__).resolve().parents[1]
if str(AI_SERVICE_ROOT) not in sys.path:
    sys.path.insert(0, str(AI_SERVICE_ROOT))

from app.assistant.chunking import HybridSemanticChunker
from app.assistant.embeddings import LocalMultilingualEmbedder
from app.assistant.ingestion import KnowledgeIngestionService
from app.assistant.source_manifest import KnowledgeManifest
from app.assistant.vector_store import PgVectorKnowledgeStore
from app.assistant.settings import AssistantSettings


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--knowledge-dir", default=str(AI_SERVICE_ROOT / "knowledge"))
    parser.add_argument("--manifest", default=None)
    parser.add_argument("--source-version", default=os.getenv("KNOWLEDGE_SOURCE_VERSION", "dev"))
    args = parser.parse_args()

    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise SystemExit("DATABASE_URL is required")

    root = Path(args.knowledge_dir)
    manifest_path = Path(args.manifest) if args.manifest else root / "sources.json"
    manifest = KnowledgeManifest.load(root, manifest_path, args.source_version)

    settings = AssistantSettings.from_env()
    store = PgVectorKnowledgeStore(database_url)
    embedder = LocalMultilingualEmbedder()
    chunker = HybridSemanticChunker(
        embedder,
        target_tokens=settings.chunk_target_tokens,
        min_tokens=settings.chunk_min_tokens,
        max_tokens=settings.chunk_max_tokens,
        similarity_threshold=settings.chunk_similarity_threshold,
    )
    service = KnowledgeIngestionService(store, embedder, chunker)

    results = [service.ingest(source) for source in manifest.sources]
    for result in results:
        print(f"{result.status:9} {result.slug}: {result.chunks} chunks")
    print(
        "Ingestion complete: "
        + ", ".join(f"{status}={sum(r.status == status for r in results)}"
                    for status in ("CREATED", "UPDATED", "UNCHANGED", "EMPTY"))
    )


if __name__ == "__main__":
    main()
