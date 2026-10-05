import json
from collections.abc import Sequence
from contextlib import contextmanager

from .schemas import KnowledgeChunk, RetrievedChunk


def _vector_literal(values: Sequence[float]) -> str:
    return "[" + ",".join(f"{value:.8f}" for value in values) + "]"


class PgVectorKnowledgeStore:
    def __init__(self, database_url: str) -> None:
        self.database_url = database_url

    @contextmanager
    def _connection(self):
        try:
            import psycopg
        except ImportError as exc:
            raise RuntimeError("psycopg is required for pgvector retrieval") from exc
        with psycopg.connect(self.database_url) as connection:
            yield connection

    def upsert_document(self, *, slug: str, title: str, category: str,
                        content_hash: str, source_name: str | None = None,
                        source_url: str | None = None,
                        source_version: str | None = None) -> int:
        sql = """
            INSERT INTO ai_knowledge_documents
                (slug, title, category, source_name, source_url, source_version, content_hash)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (slug) DO UPDATE SET
                title = EXCLUDED.title,
                category = EXCLUDED.category,
                source_name = EXCLUDED.source_name,
                source_url = EXCLUDED.source_url,
                source_version = EXCLUDED.source_version,
                content_hash = EXCLUDED.content_hash,
                active = TRUE,
                updated_at = CURRENT_TIMESTAMP
            RETURNING id
        """
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(sql, (slug, title, category, source_name, source_url,
                                 source_version, content_hash))
            return cursor.fetchone()[0]

    def replace_chunks(self, document_id: int, chunks: Sequence[KnowledgeChunk],
                       embeddings: Sequence[Sequence[float]]) -> None:
        if len(chunks) != len(embeddings):
            raise ValueError("chunks and embeddings must have the same length")
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute("DELETE FROM ai_knowledge_chunks WHERE document_id = %s", (document_id,))
            for chunk, embedding in zip(chunks, embeddings, strict=True):
                cursor.execute(
                    """INSERT INTO ai_knowledge_chunks
                       (document_id, chunk_index, content, token_count, embedding, metadata)
                       VALUES (%s, %s, %s, %s, %s::vector, %s::jsonb)""",
                    (document_id, chunk.chunk_index, chunk.content,
                     len(chunk.content.split()), _vector_literal(embedding),
                     json.dumps(chunk.metadata, ensure_ascii=False)),
                )

    def search(self, query_embedding: Sequence[float], *, limit: int = 8,
               min_similarity: float = 0.55) -> list[RetrievedChunk]:
        if limit < 1 or limit > 20:
            raise ValueError("limit must be between 1 and 20")
        sql = """
            SELECT c.id, d.slug, d.title, d.category, c.content,
                   1 - (c.embedding <=> %s::vector) AS similarity,
                   c.metadata
            FROM ai_knowledge_chunks c
            JOIN ai_knowledge_documents d ON d.id = c.document_id
            WHERE d.active = TRUE
              AND 1 - (c.embedding <=> %s::vector) >= %s
            ORDER BY c.embedding <=> %s::vector
            LIMIT %s
        """
        vector = _vector_literal(query_embedding)
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(sql, (vector, vector, min_similarity, vector, limit))
            return [RetrievedChunk(
                chunk_id=row[0], document_slug=row[1], title=row[2], category=row[3],
                content=row[4], similarity=float(row[5]), metadata=row[6] or {},
            ) for row in cursor.fetchall()]
