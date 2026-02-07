# PRIORITIES — Product Drivers and Won’t-Build List (Week 5)

This document defines what optimizes decisions and what is explicitly out of scope.

---

## Top 3 Drivers

### 1) Tenant Isolation and Safety
- Non-negotiable: strict RLS isolation, SECURITY DEFINER safety, privilege firewall, and CI gates.
- Prefer pushing guarantees into Supabase (RLS/RPCs/views/functions) over app-layer complexity.

### 2) Speed and Clarity for Solo Operators
- Optimize for fast decisions over task management.
- Minimal screens, low cognitive load, offline-first where possible.
- MAO and deal decisions must be quick, deterministic, and explainable.

### 3) Reliability and Reproducibility
- PR-only publishing; ship is the sole publisher.
- Deterministic gates: schema drift, pgTAP, definer safety audits, lints.
- Tagged releases and rollback discipline.

---

## Won’t-Build List (Explicit)

1. Full CRM features (pipelines, sequences, inboxes, dialer, automation engines).
2. Team-wide enterprise features (complex permissions matrix, department roles, SSO/SAML).
3. Built-in marketing/email/SMS blasting, lead scraping, or “growth hacking” tools.
4. Arbitrary SQL/query builder access for end users.
5. Direct table access from clients (no client-side service-role, no table reads/writes).
6. Heavy “task manager” UI (Kanban-first, assignment workflows, approvals).
7. Pro tier / multi-tier sprawl beyond Free/Trial/Core.
8. Retro-editing old migrations or bypassing PR/CI gates to “ship faster”.

---

## Decision Rule

When in doubt:
- Choose the option that strengthens tenant safety, reduces moving parts, and keeps the product fast for a solo user.
- If a feature adds complexity without improving decision speed or reliability, it is out of scope.
