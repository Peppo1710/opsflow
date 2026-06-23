-- ============================================================
-- OpsFlow: Review & Reporting Layer
-- ============================================================
-- This file creates: assignments, reports, report_versions
--
-- "reports" and "report_versions" have a chicken-and-egg
-- relationship — a report points at its current version, and
-- a version points at its parent report. We solve this with
-- a deferred ALTER TABLE at the bottom.
-- ============================================================


-- ------------------------------------------------------------
-- assignments: which pathologist is assigned to which entity.
-- released_at NULL means "currently assigned." When the
-- pathologist releases or finishes, set released_at to now().
-- This pattern lets us query history of all assignments AND
-- find current ones in one table.
-- ------------------------------------------------------------
CREATE TABLE assignments (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
    entity_id        UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    pathologist_id   UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    assigned_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    released_at      TIMESTAMPTZ,

    -- Released must be >= assigned if both are set
    CHECK (released_at IS NULL OR released_at >= assigned_at)
);

COMMENT ON TABLE  assignments IS 'Which reviewer is/was working on which entity.';
COMMENT ON COLUMN assignments.released_at IS 'NULL while currently assigned. Set when released or completed.';


-- ------------------------------------------------------------
-- reports: ONE per entity. The "container" for all versions.
-- entity_id is UNIQUE — only one report exists per case.
-- current_version_id is a pointer to the active version.
-- (We add the FK constraint AFTER report_versions exists.)
-- ------------------------------------------------------------
CREATE TABLE reports (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
    entity_id           UUID NOT NULL UNIQUE REFERENCES entities(id) ON DELETE CASCADE,
    current_version_id  UUID,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  reports IS 'One per entity. Container that points to the current report version.';


-- ------------------------------------------------------------
-- report_versions: every draft and signed version.
-- The CHECK enforces a key invariant: signed_at and signed_by
-- must either BOTH be set (the report is signed) or BOTH be
-- NULL (still a draft). No half-signed state.
--
-- Day 6 will add a trigger that prevents UPDATEs once
-- signed_at is set (true immutability).
-- ------------------------------------------------------------
CREATE TABLE report_versions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id       UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    version_number  INTEGER NOT NULL,
    body            TEXT NOT NULL,
    authored_by     UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    signed_at       TIMESTAMPTZ,
    signed_by       UUID REFERENCES users(id),

    UNIQUE (report_id, version_number),

    -- Both signature fields must agree on signed/unsigned status.
    CHECK (
        (signed_at IS NULL AND signed_by IS NULL)
        OR (signed_at IS NOT NULL AND signed_by IS NOT NULL)
    )
);

COMMENT ON TABLE report_versions IS 'Every draft and signed version. Append-only after signing.';


-- ------------------------------------------------------------
-- Close the cycle: add the FK from reports → report_versions
-- (couldn't do this in CREATE TABLE because report_versions
-- didn't exist yet).
-- ------------------------------------------------------------
ALTER TABLE reports
    ADD CONSTRAINT reports_current_version_fk
    FOREIGN KEY (current_version_id) REFERENCES report_versions(id);