
-- ============================================================
-- OpsFlow: Tenant & User Layer
-- ============================================================
-- This file creates: organizations, users, roles, user_roles
-- These tables together model "who is using the system."
-- ============================================================


-- ------------------------------------------------------------
-- organizations: each customer (lab/hospital) is one row.
-- This is the root of multi-tenancy — every business row
-- elsewhere has an organization_id pointing here.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS organizations  (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    slug        TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  organizations IS 'Tenants of the system. Each customer org is one row.';
COMMENT ON COLUMN organizations.slug IS 'URL-safe identifier like "aiims-delhi".';


-- ------------------------------------------------------------
-- users: people who log in.
-- Belongs to exactly one organization.
-- Email is unique only WITHIN an organization, not globally —
-- two different hospitals could both have dr.sharma@gmail.com.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id  UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
    email            TEXT NOT NULL,
    full_name        TEXT NOT NULL,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (organization_id, email)
);

COMMENT ON TABLE users IS 'People who can log in. Belongs to one organization.';


-- ------------------------------------------------------------
-- roles: small, fixed lookup table.
-- Using SMALLINT PK because there are only ~4 roles forever —
-- no need to spend 16 bytes per row on a UUID.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS roles (
    id    SMALLINT PRIMARY KEY,
    name  TEXT NOT NULL UNIQUE
          CHECK (name IN ('admin', 'lab_tech', 'pathologist', 'readonly'))
);

COMMENT ON TABLE roles IS 'Lookup table for user role types. Seeded inline below.';

-- Seed the four roles (this is part of the schema, not user data)
INSERT INTO roles (id, name) VALUES
    (1, 'admin'),
    (2, 'lab_tech'),
    (3, 'pathologist'),
    (4, 'readonly');


-- ------------------------------------------------------------
-- user_roles: many-to-many between users and roles.
-- One user can have multiple roles (e.g., a senior pathologist
-- might also be an admin).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_roles (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id     SMALLINT NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    granted_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (user_id, role_id)
);

COMMENT ON TABLE user_roles IS 'Join table: which users have which roles.';