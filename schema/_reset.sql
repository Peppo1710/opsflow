-- ============================================================
-- DEV RESET: wipes all OpsFlow tables.
-- Run manually when you want to rebuild from scratch.
-- The underscore prefix marks this as a tool, not a migration.
-- ============================================================

DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS report_versions CASCADE;
DROP TABLE IF EXISTS reports CASCADE;
DROP TABLE IF EXISTS assignments CASCADE;
DROP TABLE IF EXISTS device_events CASCADE;
DROP TABLE IF EXISTS jobs CASCADE;
DROP TABLE IF EXISTS devices CASCADE;
DROP TABLE IF EXISTS artifacts CASCADE;
DROP TABLE IF EXISTS entity_status_history CASCADE;
DROP TABLE IF EXISTS entities CASCADE;
DROP TABLE IF EXISTS workflow_transitions CASCADE;
DROP TABLE IF EXISTS workflow_states CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS organizations CASCADE;