-- ============================================================
-- OpsFlow: Core Business Layer
-- ============================================================
-- This file creates: entities, entity_status_history,
--                    artifacts, devices, jobs, device_events
--
-- These are the "five primitives" of OpsFlow.
-- ============================================================


-- ------------------------------------------------------------
-- entities: the things being tracked (specimens, in our demo).
-- current_state_id is denormalized for query speed — the full
-- history lives in entity_status_history. We could derive
-- current state from history every time, but it would be slow.
-- ------------------------------------------------------------
CREATE TABLE entities (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id   UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
    entity_type       TEXT NOT NULL,
    external_ref      TEXT NOT NULL,
    patient_ref       TEXT NOT NULL,
    current_state_id  SMALLINT NOT NULL REFERENCES workflow_states(id),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (organization_id, external_ref)
);

COMMENT ON TABLE  entities IS 'Things tracked through workflows. Specimens in pathology demo.';
COMMENT ON COLUMN entities.external_ref IS 'The hospital''s own case ID (e.g., "AIIMS-2026-001234").';
COMMENT ON COLUMN entities.patient_ref IS 'Anonymized patient identifier — no PII here.';


-- ------------------------------------------------------------
-- entity_status_history: every status transition, append-only.
-- Triggers on Day 6 will enforce this is only ever INSERTed.
-- BIGSERIAL because this can grow large (every state change
-- for every specimen ever).
-- ------------------------------------------------------------
CREATE TABLE entity_status_history (
    id             BIGSERIAL PRIMARY KEY,
    entity_id      UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    from_state_id  SMALLINT REFERENCES workflow_states(id),
    to_state_id    SMALLINT NOT NULL REFERENCES workflow_states(id),
    changed_by     UUID REFERENCES users(id),
    changed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes          TEXT,

    -- Sanity: can't transition to the same state
    CHECK (from_state_id IS NULL OR from_state_id <> to_state_id)
);

COMMENT ON TABLE  entity_status_history IS 'Append-only log of every state transition.';
COMMENT ON COLUMN entity_status_history.from_state_id IS 'NULL only for the very first entry (initial state).';
COMMENT ON COLUMN entity_status_history.changed_by IS 'NULL allowed for system-triggered transitions.';


-- ------------------------------------------------------------
-- artifacts: items derived from entities (slides, in our demo).
-- metadata JSONB stores domain-specific fields without
-- polluting the generic schema (stain type, magnification,
-- DICOM-style tags, etc.).
-- ------------------------------------------------------------
CREATE TABLE artifacts (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
    entity_id        UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    artifact_type    TEXT NOT NULL,
    label            TEXT NOT NULL,
    metadata         JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (entity_id, label)
);

COMMENT ON TABLE  artifacts IS 'Items derived from entities. Slides in pathology demo.';
COMMENT ON COLUMN artifacts.metadata IS 'Flexible JSON for domain-specific fields (stain, magnification, etc.).';


-- ------------------------------------------------------------
-- devices: physical equipment (scanners, microtomes).
-- status is a CHECK-constrained text instead of an ENUM so
-- it's easier to extend later without ALTER TYPE.
-- ------------------------------------------------------------
CREATE TABLE devices (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
    device_type      TEXT NOT NULL,
    model            TEXT NOT NULL,
    serial_number    TEXT NOT NULL UNIQUE,
    status           TEXT NOT NULL DEFAULT 'idle'
                     CHECK (status IN ('idle', 'busy', 'offline', 'error')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  devices IS 'Physical equipment that processes artifacts.';
COMMENT ON COLUMN devices.device_type IS 'e.g., "whole_slide_scanner", "microtome".';


-- ------------------------------------------------------------
-- jobs: one run of a device on an artifact.
-- The CHECK constraint is the interesting bit: a "completed"
-- or "failed" job MUST have both timestamps, otherwise the
-- data is corrupt and the DB refuses to store it.
-- ------------------------------------------------------------
CREATE TABLE jobs (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
    artifact_id      UUID NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    device_id        UUID NOT NULL REFERENCES devices(id) ON DELETE RESTRICT,
    status           TEXT NOT NULL DEFAULT 'queued'
                     CHECK (status IN ('queued', 'running', 'completed', 'failed', 'cancelled')),
    started_at       TIMESTAMPTZ,
    finished_at      TIMESTAMPTZ,
    duration_ms      INTEGER,
    error_message    TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- A finished job MUST have its timestamps set.
    CHECK (
        (status IN ('completed', 'failed') AND started_at IS NOT NULL AND finished_at IS NOT NULL)
        OR status IN ('queued', 'running', 'cancelled')
    ),

    -- Sanity: if both timestamps exist, finished must be after started.
    CHECK (finished_at IS NULL OR started_at IS NULL OR finished_at >= started_at)
);

COMMENT ON TABLE jobs IS 'One run of a device processing one artifact.';


-- ------------------------------------------------------------
-- device_events: HIGH-VOLUME telemetry stream.
-- This will become a partitioned table on Day 9. For now we
-- declare a composite PK (id, event_time) — even though only
-- "id" would technically suffice — because partitioned tables
-- in PostgreSQL require the partition key to be part of the PK.
-- Putting this in place now means Day 9 won't require dropping
-- and recreating the table.
-- ------------------------------------------------------------
CREATE TABLE device_events (
    id               BIGSERIAL,
    organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
    device_id        UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    job_id           UUID REFERENCES jobs(id) ON DELETE SET NULL,
    event_time       TIMESTAMPTZ NOT NULL DEFAULT now(),
    event_type       TEXT NOT NULL,
    payload          JSONB NOT NULL DEFAULT '{}'::jsonb,

    PRIMARY KEY (id, event_time)
);

COMMENT ON TABLE  device_events IS 'Telemetry stream from devices. Will be partitioned by month on Day 9.';
COMMENT ON COLUMN device_events.event_type IS 'e.g., "focus_adjust", "tile_capture", "qc_pass", "error".';