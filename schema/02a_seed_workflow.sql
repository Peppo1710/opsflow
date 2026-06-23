-- ============================================================
-- OpsFlow: Seed the pathology workflow
-- ============================================================
-- This file populates workflow_states and workflow_transitions
-- with the digital-pathology specimen lifecycle.
--
-- This is "seed data" — schema-level data that's part of the
-- system definition, not user data. Lives in schema/ folder.
-- ============================================================


-- ------------------------------------------------------------
-- Specimen states (the case lifecycle)
-- ------------------------------------------------------------
INSERT INTO workflow_states (id, entity_type, state_name, is_terminal, sort_order) VALUES
    (1,  'specimen', 'received',     FALSE,  1),
    (2,  'specimen', 'grossed',      FALSE,  2),
    (3,  'specimen', 'processed',    FALSE,  3),
    (4,  'specimen', 'embedded',     FALSE,  4),
    (5,  'specimen', 'sectioned',    FALSE,  5),
    (6,  'specimen', 'scanned',      FALSE,  6),
    (7,  'specimen', 'under_review', FALSE,  7),
    (8,  'specimen', 'reported',     FALSE,  8),
    (9,  'specimen', 'signed_out',   FALSE,  9),
    (10, 'specimen', 'archived',     TRUE,  10),
    (11, 'specimen', 'rejected',     TRUE,  99);


-- ------------------------------------------------------------
-- Allowed transitions
-- Format reminder:
--   Roles: 1=admin, 2=lab_tech, 3=pathologist, 4=readonly
-- ------------------------------------------------------------
INSERT INTO workflow_transitions (from_state_id, to_state_id, allowed_role_id) VALUES
    -- Lab tech moves specimens through processing stages
    (1, 2, 2),   -- received     -> grossed
    (2, 3, 2),   -- grossed      -> processed
    (3, 4, 2),   -- processed    -> embedded
    (4, 5, 2),   -- embedded     -> sectioned
    (5, 6, 2),   -- sectioned    -> scanned
    (6, 7, 2),   -- scanned      -> under_review

    -- Pathologist owns the review and sign-out
    (7, 8, 3),   -- under_review -> reported
    (8, 9, 3),   -- reported     -> signed_out

    -- Admin archives signed-out cases
    (9, 10, 1),  -- signed_out   -> archived

    -- Rejection path (lab tech can reject early-stage bad specimens)
    (1, 11, 2),  -- received     -> rejected
    (2, 11, 2);  -- grossed      -> rejected