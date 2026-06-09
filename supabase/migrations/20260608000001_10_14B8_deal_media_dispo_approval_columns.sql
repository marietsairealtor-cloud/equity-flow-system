-- 10.14B8 — Dispo Backend — Share Packet Photo Visibility
-- Migration 1 of 2: Add dispo approval columns to public.deal_media
-- Backward-compatible: existing rows default to is_dispo_approved = false

ALTER TABLE public.deal_media
  ADD COLUMN IF NOT EXISTS is_dispo_approved boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS dispo_approved_at  timestamptz NULL,
  ADD COLUMN IF NOT EXISTS dispo_approved_by  uuid        NULL;
