-- ============================================================
-- OpsFlow: Audit Log
-- ============================================================
-- This file creates: audit_log
--
-- Append-only log of every change to every business table.
-- Day 6 will add a trigger function that AUTOMATICALLY writes
-- to this table on INSERT/UPDATE/DELETE of any business table —
-- application code never writes here directly.
-- ============================================================


-- ------------------------------------------------------------
-- audit_log: who changed what, when, with the before/after rows.
--
-- record_id is TEXT (not UUID) because different tables have
-- different PK types — UUID, BIGINT, even composite keys.
-- Text is the lowest common denominator.
--
-- old_row and new_row are JSONB snapshots:
--   INSERT → old_row NULL, new_row = the inserted row
--   UPDATE → both set, you can diff them
--   DELETE → old_row = the row that was deleted, new_row NULL
-- ------------------------------------------------------------
CREATE TABLE audit_log (
    id               BIGSERIAL PRIMARY KEY,
    organization_id  UUID,
    table_name       TEXT NOT NULL,
    record_id        TEXT NOT NULL,
    action           TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_row          JSONB,
    new_row          JSONB,
    changed_by       UUID REFERENCES users(id),
    changed_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  audit_log IS 'Append-only audit trail. Populated by triggers on Day 6. NEVER write from app code.';
COMMENT ON COLUMN audit_log.record_id IS 'PK of the changed row, stored as text to handle multiple PK types.';
COMMENT ON COLUMN audit_log.old_row IS 'Snapshot of row before change. NULL on INSERT.';
COMMENT ON COLUMN audit_log.new_row IS 'Snapshot of row after change. NULL on DELETE.';