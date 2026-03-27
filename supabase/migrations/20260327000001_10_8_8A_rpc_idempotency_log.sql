-- Migration: 10.8.8A -- RPC Idempotency Log Table
-- Creates public.rpc_idempotency_log required by create_tenant_v1.
-- REVOKE ALL from anon and authenticated; written only via SECURITY DEFINER RPCs.

CREATE TABLE public.rpc_idempotency_log (
  id              uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id         uuid        NOT NULL,
  idempotency_key text        NOT NULL,
  rpc_name        text        NOT NULL,
  result_json     jsonb       NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key, rpc_name)
);

ALTER TABLE public.rpc_idempotency_log ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.rpc_idempotency_log FROM anon;
REVOKE ALL ON TABLE public.rpc_idempotency_log FROM authenticated;