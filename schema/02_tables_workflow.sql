-- ============================================================
-- OpsFlow: Workflow Definition Layer
-- ============================================================
-- This file creates: workflow_states, workflow_transitions
--
-- These two tables ARE the state machine. The DB enforces
-- legal transitions by joining against them — no application
-- code needed. Adding a new workflow stage tomorrow is one
-- INSERT, not a schema migration.
-- ============================================================


-- ------------------------------------------------------------
-- workflow_states: every possible stage in any workflow.
-- entity_type lets us reuse the same table for different
-- domains (specimen workflow, order workflow, claim workflow).
-- ------------------------------------------------------------
CREATE TABLE workflow_states (
    id           SMALLINT PRIMARY KEY,
    entity_type  TEXT NOT NULL,
    state_name   TEXT NOT NULL,
    is_terminal  BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order   SMALLINT NOT NULL,

    UNIQUE (entity_type, state_name)
);

COMMENT ON TABLE  workflow_states IS 'All possible workflow stages, keyed by entity_type.';
COMMENT ON COLUMN workflow_states.is_terminal IS 'TRUE if no further transitions are allowed from this state.';
COMMENT ON COLUMN workflow_states.sort_order IS 'Display order in UI. Independent of id.';


-- ------------------------------------------------------------
-- workflow_transitions: which transitions are legal.
-- A row here means "from this state, you can go to that state,
-- IF you have this role." Missing row = transition forbidden.
--
-- Multiple rows with the same (from, to) but different roles
-- mean "either of these roles can do it."
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS workflow_transitions (
    from_state_id    SMALLINT NOT NULL REFERENCES workflow_states(id),
    to_state_id      SMALLINT NOT NULL REFERENCES workflow_states(id),
    allowed_role_id  SMALLINT NOT NULL REFERENCES roles(id),

    PRIMARY KEY (from_state_id, to_state_id, allowed_role_id),

    -- Sanity: a transition must actually move somewhere
    CHECK (from_state_id <> to_state_id)
);

COMMENT ON TABLE workflow_transitions IS 'Legal state transitions. (from, to, role) tuples define what is allowed.';