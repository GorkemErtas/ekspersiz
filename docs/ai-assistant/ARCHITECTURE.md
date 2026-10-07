# EksperSiz AI Assistant — Architecture

## Goal

Build a domain-restricted Turkish vehicle assistant that answers only automotive and EksperSiz questions. It combines retrieval-augmented generation (RAG) for curated automotive knowledge with authorized backend tools for user-specific data.

## Core rule

Private user data is **not embedded into the vector store**. Vehicle, inspection, damage, reminder and account context is fetched just-in-time through authenticated Spring Boot tools. Only curated, non-personal knowledge is chunked and embedded.

## Request pipeline

1. Flutter sends text (voice is converted to text on-device in a later phase).
2. Spring Security authenticates the user.
3. AI access service checks trial/subscription, temporary lock and daily quota.
4. A zero/low-cost domain guard rejects obvious out-of-scope requests before an LLM call.
5. In-scope requests are classified into an intent.
6. The orchestrator selects one or both context sources:
   - **RAG:** general automotive/EksperSiz knowledge.
   - **Tools:** live user/vehicle/inspection/damage/reminder data.
7. RAG queries are embedded and searched with cosine similarity in PostgreSQL/pgvector.
8. Only the top relevant chunks and minimum necessary tool results are added to the prompt.
9. The LLM must answer from supplied evidence/context. If evidence is insufficient, it must say so rather than guess.
10. A successful answer consumes one daily question. Rejected/out-of-scope requests do not consume quota.

## RAG design

- Vector store: PostgreSQL + pgvector (no separate paid vector database).
- Embedding dimension: 384.
- Target embedding model: multilingual E5-small class local embedding model.
- Chunking: heading-aware recursive chunking, target ~350–500 tokens, ~60-token overlap.
- Retrieval: cosine similarity, initial top-k 8, then score threshold + final top 4 context chunks.
- Metadata: category, source, document version and headings.
- Index: HNSW cosine index.
- Knowledge sources must be curated/versioned and carry source metadata.

## Supported intents (v1)

- VEHICLE_GENERAL
- INSPECTION
- MAINTENANCE
- DRIVING_USAGE
- SAFETY
- VEHICLE_SPEC
- USER_VEHICLE
- DAMAGE_HISTORY
- REMINDER
- APP_HELP
- OUT_OF_SCOPE

## Authorized tools (planned)

- getMyVehicles
- getPrimaryVehicle
- getVehicleOverview
- getInspectionStatus
- getDamageHistory
- getUpcomingReminders

Tools always derive the user identity from the authenticated request. The LLM never receives arbitrary database access and never chooses a user id.

## Access and quota

- AI Assistant is separate from the existing damage-analysis allowance.
- First activation starts a one-time 30-day trial.
- After trial, access requires the AI Assistant monthly product.
- Daily successful-answer limit: 3.
- Out-of-scope attempts do not consume the daily limit.
- Repeated abuse increments warnings; after 3 daily out-of-scope attempts, AI access is temporarily locked for 24 hours. The paid subscription itself is not cancelled automatically.
- Server/LLM failures do not consume quota.

## Cost controls

- Domain rejection before LLM where confidence is high.
- Local embeddings; embeddings are generated once per knowledge chunk and reused.
- pgvector instead of a separate vector SaaS.
- Top-k retrieval rather than sending the whole knowledge base.
- Bounded conversation context with summary + recent turns.
- Short output limits.
- Cache stable retrieval results where useful.
- Daily quota enforced server-side.

## Evaluation

The agent ships with an evaluation set containing in-domain, out-of-domain, ambiguous, tool-required, RAG-required and adversarial prompts. Track:

- domain classification accuracy
- out-of-domain rejection rate
- retrieval hit rate / Recall@k
- correct tool selection
- grounded-answer rate
- unauthorized-data-access attempts (target: zero)
- average input/output tokens and cost per successful answer

## Delivery phases

1. Persistence + access/quota foundation.
2. Knowledge ingestion: cleaning, chunking, embeddings and pgvector.
3. Semantic retrieval API + retrieval tests.
4. Agent orchestration, domain guard and grounded generation.
5. Authenticated user-data tools.
6. Flutter text chat + remaining quota UI.
7. RevenueCat AI monthly product + one-time 30-day trial.
8. Evaluation/observability and prompt-injection tests.
9. On-device speech-to-text/text-to-speech.
