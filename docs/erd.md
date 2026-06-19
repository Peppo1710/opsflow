# OpsFlow — Entity Relationship Design

## Tables overview (15 total)

### Tenant & user layer
1. **organizations** — customer companies (each lab/hospital)
2. **users** — people who log in
3. **roles** — admin, lab_tech, pathologist, readonly
4. **user_roles** — which users have which roles (many-to-many)

### Workflow definition layer (state machine as data)
5. **workflow_states** — every possible stage (e.g., "received", "scanned")
6. **workflow_transitions** — which states can move to which states

### Core business layer (the five primitives)
7. **entities** — the specimens/cases being tracked
8. **entity_status_history** — every status change with timestamp + actor
9. **artifacts** — slides derived from entities
10. **devices** — scanners, microtomes
11. **jobs** — one device processing one artifact
12. **device_events** — telemetry stream (large, will be partitioned)

### Review & reporting layer
13. **assignments** — which pathologist is assigned to which entity
14. **reports** — one per entity (the current/latest report)
15. **report_versions** — every draft and signed version of every report

### Cross-cutting
16. **audit_log** — automatic record of every change to every business table

## Table columns

### organizations
- id (UUID, PK)
- name (text, not null)
- slug (text, unique, not null) — e.g., "aiims-delhi"
- created_at, updated_at

### users
- id (UUID, PK)
- organization_id (FK → organizations)
- email (text, unique)
- full_name (text)
- created_at, updated_at

### roles
- id (smallint, PK)
- name (text, unique) — 'admin', 'lab_tech', 'pathologist', 'readonly'

### user_roles
- user_id (FK → users)
- role_id (FK → roles)
- PK (user_id, role_id)

### workflow_states
- id (smallint, PK)
- entity_type (text) — 'specimen', 'order', etc.
- state_name (text) — 'received', 'grossed', 'scanned', etc.
- is_terminal (boolean) — true for 'signed_out', 'archived'
- sort_order (smallint) — display order
- UNIQUE (entity_type, state_name)

### workflow_transitions
- from_state_id (FK → workflow_states)
- to_state_id (FK → workflow_states)
- allowed_role_id (FK → roles) — who can perform this transition
- PK (from_state_id, to_state_id)

### entities (the specimens/cases)
- id (UUID, PK)
- organization_id (FK → organizations)
- entity_type (text) — 'specimen' for pathology demo
- external_ref (text) — hospital's own case ID
- patient_ref (text) — anonymized patient identifier
- current_state_id (FK → workflow_states)
- created_at, updated_at
- INDEX on (organization_id, current_state_id)

### entity_status_history
- id (bigserial, PK)
- entity_id (FK → entities)
- from_state_id (FK → workflow_states, nullable for first state)
- to_state_id (FK → workflow_states)
- changed_by (FK → users)
- changed_at (timestamptz)
- notes (text, nullable)
- INDEX on (entity_id, changed_at)

### artifacts (the slides)
- id (UUID, PK)
- organization_id (FK → organizations)
- entity_id (FK → entities)
- artifact_type (text) — 'slide' for pathology
- label (text) — e.g., "Block A, Slide 3"
- metadata (jsonb) — stain type, magnification, etc.
- created_at, updated_at

### devices
- id (UUID, PK)
- organization_id (FK → organizations)
- device_type (text) — 'whole_slide_scanner', 'microtome'
- model (text) — 'MorphoLens-V2'
- serial_number (text, unique)
- status (text) — 'idle', 'busy', 'offline', 'error'
- created_at, updated_at

### jobs
- id (UUID, PK)
- organization_id (FK → organizations)
- artifact_id (FK → artifacts)
- device_id (FK → devices)
- status (text) — 'queued', 'running', 'completed', 'failed'
- started_at (timestamptz, nullable)
- finished_at (timestamptz, nullable)
- duration_ms (int, nullable)
- error_message (text, nullable)
- INDEX on (organization_id, status)

### device_events (HIGH VOLUME — will be partitioned by month)
- id (bigserial)
- organization_id (FK)
- device_id (FK → devices)
- job_id (FK → jobs, nullable)
- event_time (timestamptz, not null) — partition key
- event_type (text) — 'focus_adjust', 'tile_capture', 'qc_pass', 'error'
- payload (jsonb)
- PK (id, event_time) — composite because of partitioning
- INDEX on (device_id, event_time)

### assignments
- id (UUID, PK)
- organization_id (FK)
- entity_id (FK → entities)
- pathologist_id (FK → users)
- assigned_at (timestamptz)
- released_at (timestamptz, nullable)
- INDEX on (pathologist_id, released_at)

### reports
- id (UUID, PK)
- organization_id (FK)
- entity_id (FK → entities, UNIQUE)
- current_version_id (FK → report_versions, nullable)
- created_at, updated_at

### report_versions
- id (UUID, PK)
- report_id (FK → reports)
- version_number (int)
- body (text)
- authored_by (FK → users)
- created_at (timestamptz)
- signed_at (timestamptz, nullable) — non-null means signed (immutable)
- signed_by (FK → users, nullable)
- UNIQUE (report_id, version_number)

### audit_log (append-only)
- id (bigserial, PK)
- organization_id (FK, nullable)
- table_name (text)
- record_id (text) — the PK of the changed row, as text
- action (text) — 'INSERT', 'UPDATE', 'DELETE'
- old_row (jsonb, nullable)
- new_row (jsonb, nullable)
- changed_by (FK → users, nullable)
- changed_at (timestamptz, default now())
- INDEX on (table_name, record_id)