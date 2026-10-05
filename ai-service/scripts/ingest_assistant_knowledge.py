import argparse
import hashlib
import os
from pathlib import Path

AI_SERVICE_ROOT = Path(__file__).resolve().parents[1]\nif str(AI_SERVICE_ROOT) not in sys.path:\n    sys.path.insert(0, str(AI_SERVICE_ROOT))\n\nfrom app.assistant.chunking import HeadingAwareChunker
from app.assistant.embeddings import LocalMultilingualEmbedder
from app.assistant.schemas import KnowledgeDocument
from app.assistant.vector_store import PgVectorKnowledgeStore


def ingest_file(path: Path, category: str, store: PgVectorKnowledgeStore,
                embedder: LocalMultilingualEmbedder, chunker: HeadingAwareChunker) -> int:
    content = path.read_text(encoding="utf-8").strip()
    if not content:
        return 0
    slug = path.stem.replace("_", "-").lower()
    title = next((line.lstrip("# ").strip() for line in content.splitlines()
                  if line.startswith("#")), path.stem.replace("_", " ").title())
    digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
    document = KnowledgeDocument(slug=slug, title=title, category=category, content=content)
    chunks = chunker.chunk(document)
    embeddings = embedder.embed_passages([chunk.content for chunk in chunks])
    document_id = store.upsert_document(
        slug=slug, title=title, category=category, content_hash=digest,
        source_name="EksperSiz curated knowledge", source_version="v1",
    )
    store.replace_chunks(document_id, chunks, embeddings)
    return len(chunks)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--knowledge-dir", default=str(AI_SERVICE_ROOT / "knowledge"))
    args = parser.parse_args()
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise SystemExit("DATABASE_URL is required")
    root = Path(args.knowledge_dir)
    store = PgVectorKnowledgeStore(database_url)
    embedder = LocalMultilingualEmbedder()
    chunker = HeadingAwareChunker()
    total = 0
    for path in sorted(root.rglob("*.md")):
        category = path.parent.name.upper().replace("-", "_")
        count = ingest_file(path, category, store, embedder, chunker)
        total += count
        print(f"{path}: {count} chunks")
    print(f"Ingestion complete: {total} chunks")


if __name__ == "__main__":
    main()
