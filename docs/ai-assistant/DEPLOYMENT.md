# AI Assistant Deployment

## Principles

The damage-analysis service and AI Assistant share a deployment unit today, but they have separate readiness semantics. Assistant rollout must never make the existing damage-analysis health check depend on RAG availability.

Knowledge ingestion is a release/admin operation, not an application startup task. This prevents duplicate embeddings, long cold starts and partially published indexes.

## Production sequence

1. Back up PostgreSQL.
2. Verify the target PostgreSQL supports the `vector` extension.
3. Apply Flyway migrations.
4. Deploy the AI service image. The pinned E5 embedding model is baked into the image and production uses local-only loading.
5. Run the knowledge ingestion command explicitly against the target database.
6. Verify `/health` for the existing AI service.
7. Verify `/api/v1/assistant/readiness` reports pgvector enabled and at least one active document.
8. Run the assistant evaluation/smoke suite.
9. Enable/expose the assistant UI only after readiness and evaluation pass.

## Rollback

Application rollback and knowledge rollback are separate operations. Existing document versions are retained as `SUPERSEDED`; do not delete historical versions during normal publishing. A future admin command can atomically reactivate a prior version if a knowledge release regresses.

## Knowledge updates

- Unchanged content hashes are skipped before chunking/embedding.
- Changed documents create a new version; the previous ACTIVE version becomes SUPERSEDED.
- Retrieval uses only ACTIVE documents inside their validity window.
- Never ingest private user or vehicle history data.
- Curated Markdown is the preferred maintained format.
- External PDFs will pass through a parser/normalizer before the same ingestion service.

## Configuration

- `DATABASE_URL`: PostgreSQL connection.
- `ASSISTANT_EMBEDDING_MODEL`: pinned SentenceTransformer model.
- `ASSISTANT_EMBEDDING_LOCAL_ONLY=true`: production guard against runtime model downloads.
- `KNOWLEDGE_SOURCE_VERSION`: release identifier supplied by CI/admin ingestion.
- `ASSISTANT_CHUNK_TARGET_TOKENS`: target semantic chunk size, default 420.
- `ASSISTANT_CHUNK_MIN_TOKENS`: minimum semantic chunk size, default 120.
- `ASSISTANT_CHUNK_MAX_TOKENS`: hard chunk ceiling, default 560.
- `ASSISTANT_CHUNK_SIMILARITY_THRESHOLD`: semantic boundary threshold, default 0.72.
- `ASSISTANT_RETRIEVAL_CANDIDATE_K`: vector candidates, default 8.
- `ASSISTANT_RETRIEVAL_FINAL_K`: context chunks returned, default 4.
- `ASSISTANT_RETRIEVAL_MIN_SIMILARITY`: retrieval floor, default 0.55.

RAG tuning values are validated at startup/use. Keep production changes versioned in Railway/environment history and evaluate retrieval quality before and after threshold changes.

Secrets must remain environment variables and must not be committed to the repository.

## Future scaling

If the assistant load becomes materially larger than damage analysis, split the assistant into its own deployable service without changing the Spring Boot contract. The current router/retriever/ingestion boundaries are intentionally isolated for that migration.
