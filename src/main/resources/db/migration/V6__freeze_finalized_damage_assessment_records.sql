ALTER TABLE damage_assessment_records
    ADD COLUMN snapshot_json TEXT,
    ADD COLUMN content_hash VARCHAR(64);

ALTER TABLE damage_assessment_records
    ADD CONSTRAINT ck_damage_assessment_record_finalized_snapshot
    CHECK (
        status <> 'FINALIZED'
        OR (
            snapshot_json IS NOT NULL
            AND content_hash IS NOT NULL
            AND char_length(content_hash) = 64
        )
    );

CREATE INDEX idx_damage_assessment_records_content_hash
    ON damage_assessment_records(content_hash);
