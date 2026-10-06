import json
from collections.abc import Sequence
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import date

from .schemas import KnowledgeChunk, RetrievedChunk


def _vector_literal(values: Sequence[float]) -> str:
    return "[" + ",".join(f"{value:.8f}" for value in values) + "]"


@dataclass(frozen=True)
class StoredDocument:
    id: int
    content_hash: str
    source_version: str | None


class KnowledgeVersionConflict(ValueError):
    pass


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

    def readiness(self) -> dict[str, object]:
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute("SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector')")
            vector_enabled = bool(cursor.fetchone()[0])
            cursor.execute(
                """SELECT COUNT(*) FROM ai_knowledge_documents
                   WHERE lifecycle_status = 'ACTIVE'
                     AND (valid_from IS NULL OR valid_from <= CURRENT_DATE)
                     AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)"""
            )
            active_documents = int(cursor.fetchone()[0])
            cursor.execute(
                """SELECT COUNT(*) FROM ai_knowledge_chunks c
                   JOIN ai_knowledge_documents d ON d.id = c.document_id
                   WHERE d.lifecycle_status = 'ACTIVE'
                     AND (d.valid_from IS NULL OR d.valid_from <= CURRENT_DATE)
                     AND (d.valid_until IS NULL OR d.valid_until >= CURRENT_DATE)"""
            )
            active_chunks = int(cursor.fetchone()[0])
            cursor.execute(
                """SELECT format_type(atttypid, atttypmod)
                   FROM pg_attribute
                   WHERE attrelid = 'ai_knowledge_chunks'::regclass
                     AND attname = 'embedding'
                     AND NOT attisdropped"""
            )
            dimension_row = cursor.fetchone()
            embedding_type = str(dimension_row[0]) if dimension_row else ""
            embedding_dimensions = 384 if embedding_type == "vector(384)" else 0
            return {
                "database": True,
                "pgvector": vector_enabled,
                "active_documents": active_documents,
                "active_chunks": active_chunks,
                "embedding_dimensions": embedding_dimensions,
            }

    def find_active_document(self, slug: str) -> StoredDocument | None:
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                """SELECT id, content_hash, source_version
                   FROM ai_knowledge_documents
                   WHERE slug = %s AND lifecycle_status = 'ACTIVE'
                   LIMIT 1""",
                (slug,),
            )
            row = cursor.fetchone()
            return StoredDocument(row[0], row[1], row[2]) if row else None

    def find_version(self, slug: str, source_version: str) -> StoredDocument | None:
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(
                "SELECT id, content_hash, source_version FROM ai_knowledge_documents WHERE slug = %s AND source_version = %s LIMIT 1",
                (slug, source_version),
            )
            row = cursor.fetchone()
            return StoredDocument(row[0], row[1], row[2]) if row else None

    @staticmethod
    def _lock_slug(cursor, slug: str) -> None:
        # Transaction-scoped lock serializes publication for the same stable source.
        cursor.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s, 0))", (slug,))

    @staticmethod
    def _find_version_with_cursor(cursor, slug: str,
                                  source_version: str) -> StoredDocument | None:
        cursor.execute(
            """SELECT id, content_hash, source_version
               FROM ai_knowledge_documents
               WHERE slug = %s AND source_version = %s
               LIMIT 1""",
            (slug, source_version),
        )
        row = cursor.fetchone()
        return StoredDocument(row[0], row[1], row[2]) if row else None

    @staticmethod
    def _insert_draft(cursor, slug: str, title: str, category: str,
                      content_hash: str, source_name: str | None,
                      source_url: str | None, source_version: str,
                      authority: str, language: str, market: str | None,
                      valid_from: date | None, valid_until: date | None) -> int:
        cursor.execute(
            """INSERT INTO ai_knowledge_documents
               (slug, title, category, source_name, source_url, source_version,
                content_hash, active, lifecycle_status, authority, language, market,
                valid_from, valid_until)
               VALUES (%s,%s,%s,%s,%s,%s,%s,FALSE,'DRAFT',%s,%s,%s,%s,%s)
               RETURNING id""",
            (slug, title, category, source_name, source_url, source_version,
             content_hash, authority, language, market, valid_from, valid_until),
        )
        return cursor.fetchone()[0]

    @staticmethod
    def _insert_chunks(cursor, document_id: int, chunks: Sequence[KnowledgeChunk],
                       embeddings: Sequence[Sequence[float]]) -> None:
        for chunk, embedding in zip(chunks, embeddings, strict=True):
            cursor.execute(
                """INSERT INTO ai_knowledge_chunks
                   (document_id, chunk_index, content, token_count, embedding, metadata)
                   VALUES (%s,%s,%s,%s,%s::vector,%s::jsonb)""",
                (document_id, chunk.chunk_index, chunk.content,
                 len(chunk.content.split()), _vector_literal(embedding),
                 json.dumps(chunk.metadata, ensure_ascii=False)),
            )

    @staticmethod
    def _activate(cursor, document_id: int, slug: str) -> None:
        cursor.execute(
            "UPDATE ai_knowledge_documents SET lifecycle_status = 'SUPERSEDED', active = FALSE, superseded_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE slug = %s AND lifecycle_status = 'ACTIVE'",
            (slug,),
        )
        cursor.execute(
            "UPDATE ai_knowledge_documents SET lifecycle_status = 'ACTIVE', active = TRUE, updated_at = CURRENT_TIMESTAMP WHERE id = %s AND lifecycle_status = 'DRAFT'",
            (document_id,),
        )
        if cursor.rowcount != 1:
            raise RuntimeError("staged knowledge document could not be activated")

    def publish_version(self, *, slug: str, title: str, category: str,
                        content_hash: str, source_name: str | None,
                        source_url: str | None, source_version: str,
                        chunks: Sequence[KnowledgeChunk],
                        embeddings: Sequence[Sequence[float]],
                        authority: str = "CURATED", language: str = "tr",
                        market: str | None = None,
                        valid_from: date | None = None,
                        valid_until: date | None = None) -> int:
        if len(chunks) != len(embeddings):
            raise ValueError("chunks and embeddings must have the same length")
        if not chunks:
            raise ValueError("knowledge version cannot be published without chunks")

        with self._connection() as connection, connection.cursor() as cursor:
            self._lock_slug(cursor, slug)
            existing = self._find_version_with_cursor(cursor, slug, source_version)
            if existing:
                if existing.content_hash == content_hash:
                    return existing.id
                raise KnowledgeVersionConflict(
                    f"{slug} source_version={source_version} already exists with different content; publish a new version"
                )

            document_id = self._insert_draft(
                cursor, slug, title, category, content_hash, source_name,
                source_url, source_version, authority, language, market,
                valid_from, valid_until
            )
            self._insert_chunks(cursor, document_id, chunks, embeddings)
            self._activate(cursor, document_id, slug)
            return document_id

    def search(self, query_embedding: Sequence[float], *, limit: int = 8,
               min_similarity: float = 0.55) -> list[RetrievedChunk]:
        if limit < 1 or limit > 20:
            raise ValueError("limit must be between 1 and 20")
        sql = """
            SELECT c.id, d.slug, d.title, d.category, c.content,
                   1 - (c.embedding <=> %s::vector) AS similarity,
                   d.market, d.authority, d.source_version, c.metadata
            FROM ai_knowledge_chunks c
            JOIN ai_knowledge_documents d ON d.id = c.document_id
            WHERE d.lifecycle_status = 'ACTIVE'
              AND (d.valid_from IS NULL OR d.valid_from <= CURRENT_DATE)
              AND (d.valid_until IS NULL OR d.valid_until >= CURRENT_DATE)
              AND 1 - (c.embedding <=> %s::vector) >= %s
            ORDER BY c.embedding <=> %s::vector
            LIMIT %s
        """
        vector = _vector_literal(query_embedding)
        with self._connection() as connection, connection.cursor() as cursor:
            cursor.execute(sql, (vector, vector, min_similarity, vector, limit))
            return [RetrievedChunk(
                chunk_id=row[0], document_slug=row[1], title=row[2], category=row[3],
                content=row[4], similarity=float(row[5]), market=row[6],
                authority=row[7], source_version=row[8], metadata=row[9] or {},
            ) for row in cursor.fetchall()]
