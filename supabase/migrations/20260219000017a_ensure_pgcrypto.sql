-- 20260219000017a_ensure_pgcrypto.sql
-- Prerequisite: ensure pgcrypto extension exists before share_tokens migration.
-- Forward-only plain SQL. No DO blocks. No dynamic SQL. No double-dollar tags.

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
