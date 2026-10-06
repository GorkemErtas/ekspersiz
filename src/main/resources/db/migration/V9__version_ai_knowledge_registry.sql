ALTER TABLE ai_knowledge_documents
    DROP CONSTRAINT ai_knowledge_documents_slug_key;

ALTER TABLE ai_knowledge_documents
    ADD COLUMN lifecycle_status VARCHAR(24) NOT NULL DEFAULT 'ACTIVE',
    ADD COLUMN authority VARCHAR(24) NOT NULL DEFAULT 'CURATED',
    ADD COLUMN language VARCHAR(12) NOT NULL DEFAULT 'tr',
    ADD COLUMN market VARCHAR(24),
    ADD COLUMN valid_from DATE,
    ADD COLUMN valid_until DATE,
    ADD COLUMN superseded_at TIMESTAMP(6) WITHOUT TIME ZONE;

ALTER TABLE ai_knowledge_documents
    ADD CONSTRAINT chk_ai_knowledge_lifecycle
        CHECK (lifecycle_status IN ('DRAFT', 'ACTIVE', 'SUPERSEDED', 'ARCHIVED')),
    ADD CONSTRAINT chk_ai_knowledge_authority
        CHECK (authority IN ('OFFICIAL', 'VERIFIED', 'CURATED')),
    ADD CONSTRAINT chk_ai_knowledge_validity
        CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until >= valid_from),
    ADD CONSTRAINT uk_ai_knowledge_slug_version UNIQUE (slug, source_version);

CREATE UNIQUE INDEX uk_ai_knowledge_active_slug
    ON ai_knowledge_documents(slug)
    WHERE lifecycle_status = 'ACTIVE';

CREATE INDEX idx_ai_knowledge_active_category_market
    ON ai_knowledge_documents(category, market)
    WHERE lifecycle_status = 'ACTIVE';

UPDATE ai_knowledge_documents
SET lifecycle_status = CASE WHEN active THEN 'ACTIVE' ELSE 'ARCHIVED' END;
