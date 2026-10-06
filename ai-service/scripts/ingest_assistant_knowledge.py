import argparse
import os
import sys
from pathlib import Path

AI_SERVICE_ROOT = Path(__file__).resolve().parents[1]
if str(AI_SERVICE_ROOT) not in sys.path:
    sys.path.insert(0, str(AI_SERVICE_ROOT))

from app.assistant.chunking import HybridSemanticChunker
from app.assistant.embeddings import LocalMultilingualEmbedder
from app.assistant.ingestion import KnowledgeIngestionService, KnowledgeSource
from app.assistant.vector_store import PgVectorKnowledgeStore


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--knowledge-dir", default=str(AI_SERVICE_ROOT / "knowledge"))
    parser.add_argument("--source-version", default=os.getenv("KNOWLEDGE_SOURCE_VERSION", "dev"))
    args = parser.parse_args()

    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise SystemExit("DATABASE_URL is required")

    root = Path(args.knowledge_dir)
    store = PgVectorKnowledgeStore(database_url)
    embedder = LocalMultilingualEmbedder()
    service = KnowledgeIngestionService(
        store, embedder, HybridSemanticChunker(embedder)
    )

    results = []
    for path in sorted(root.rglob("*.md")):
        category = path.parent.name.upper().replace("-", "_")
        results.append(service.ingest(KnowledgeSource(
            path=path,
            category=category,
            source_name="EksperSiz curated knowledge",
            source_version=args.source_version,
        )))

    for result in results:
        print(f"{result.status:9} {result.slug}: {result.chunks} chunks")
    print(
        "Ingestion complete: "
        + ", ".join(f"{status}={sum(r.status == status for r in results)}"
                    for status in ("CREATED", "UPDATED", "UNCHANGED", "EMPTY"))
    )


if __name__ == "__main__":
    main()
