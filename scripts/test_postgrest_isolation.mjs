// scripts/test_postgrest_isolation.mjs
// 6.3 — PostgREST HTTP isolation tests via RPC surface
// Proves CONTRACTS.md S7/S12: no direct table access, tenant isolation via RPCs
import { createRequire } from 'module';
import { execSync } from 'child_process';
const require = createRequire(import.meta.url);
const jwt = require('jsonwebtoken');

const API_URL = 'http://127.0.0.1:54321';
const JWT_SECRET = 'super-secret-jwt-token-with-at-least-32-characters-long';
const TENANT_A = 'a0000000-0000-0000-0000-000000000001';
const TENANT_B = 'b0000000-0000-0000-0000-000000000001';

function mintJwt(tenantId, role) {
  return jwt.sign(
    { role, iss: 'supabase', tenant_id: tenantId, aud: 'authenticated' },
    JWT_SECRET,
    { expiresIn: '1h' }
  );
}

const anonToken = jwt.sign(
  { role: 'anon', iss: 'supabase', aud: 'authenticated' },
  JWT_SECRET,
  { expiresIn: '1h' }
);

function seed() {
  const sql = `DELETE FROM public.deals WHERE id IN ('a2000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000002'); INSERT INTO public.deals (id, tenant_id, row_version, calc_version) VALUES ('a2000000-0000-0000-0000-000000000001','${TENANT_A}',1,1),('a2000000-0000-0000-0000-000000000002','${TENANT_A}',1,1),('b2000000-0000-0000-0000-000000000001','${TENANT_B}',1,1),('b2000000-0000-0000-0000-000000000002','${TENANT_B}',1,1);`;
  execSync(`docker exec supabase_db_equity-flow-system psql -U postgres -c "${sql}"`, { stdio: 'pipe' });
  console.log('# Seeded 4 rows (2 per tenant) via psql');
}

function refreshSchemaCache() {
  try {
    execSync('docker kill -s SIGUSR1 supabase_rest_equity-flow-system', { stdio: 'pipe' });
  } catch (_) { /* container may already be fresh */ }
}

async function rpcPost(rpcName, body, token) {
  const res = await fetch(`${API_URL}/rest/v1/rpc/${rpcName}`, {
    method: 'POST',
    headers: {
      'apikey': anonToken,
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json().catch(() => null) };
}

async function httpGet(path, token) {
  const res = await fetch(`${API_URL}/rest/v1/${path}`, {
    headers: {
      'apikey': anonToken,
      'Authorization': `Bearer ${token}`,
    },
  });
  return { status: res.status, body: await res.json().catch(() => null) };
}

let passed = 0;
let failed = 0;

function assert(name, condition) {
  if (condition) {
    console.log(`ok - ${name}`);
    passed++;
  } else {
    console.log(`FAIL - ${name}`);
    failed++;
  }
}

async function run() {
  console.log('# PostgREST Tenant Isolation HTTP Tests (RPC surface)');
  console.log('# Proves CONTRACTS.md S7/S12: RPC-only, no direct table access');
  console.log(`# API: ${API_URL}`);
  console.log('');

  seed();
  refreshSchemaCache();
  await new Promise(r => setTimeout(r, 3000));
  console.log('# PostgREST schema cache refreshed');
  console.log('');

  const tokenA = mintJwt(TENANT_A, 'authenticated');
  const tokenB = mintJwt(TENANT_B, 'authenticated');

  // Test 1: Tenant A list_deals_v1 returns ok + own rows only
  const r1 = await rpcPost('list_deals_v1', { p_limit: 100 }, tokenA);
  assert('Tenant A: list_deals_v1 returns 200', r1.status === 200);
  assert('Tenant A: list_deals_v1 ok=true', r1.body?.ok === true);
  const itemsA = r1.body?.data?.items || [];
  assert('Tenant A: list_deals_v1 returns >= 2 items', itemsA.length >= 2);
  const allOwnA = itemsA.every(i => i.tenant_id === TENANT_A);
  assert('Tenant A: all items belong to Tenant A', allOwnA);

  // Test 2: Tenant B list_deals_v1 returns only B rows
  const r2 = await rpcPost('list_deals_v1', { p_limit: 100 }, tokenB);
  assert('Tenant B: list_deals_v1 returns 200', r2.status === 200);
  const itemsB = r2.body?.data?.items || [];
  assert('Tenant B: list_deals_v1 returns >= 2 items', itemsB.length >= 2);
  const allOwnB = itemsB.every(i => i.tenant_id === TENANT_B);
  assert('Tenant B: all items belong to Tenant B', allOwnB);
  const noLeakB = itemsB.every(i => i.tenant_id !== TENANT_A);
  assert('Tenant B: zero Tenant A rows leaked', noLeakB);

  // Test 3: Tenant A create_deal_v1 binds to A
  const r3 = await rpcPost('create_deal_v1', { p_id: 'a2000000-0000-0000-0000-000000000077' }, tokenA);
  assert('Tenant A: create_deal_v1 ok=true', r3.body?.ok === true);
  assert('Tenant A: created deal bound to Tenant A', r3.body?.data?.tenant_id === TENANT_A);

  // Test 4: direct table access blocked (S12)
  const r4 = await httpGet('deals?select=*', tokenA);
  const directBlocked = r4.status === 404 || r4.status === 403 || (r4.status === 200 && Array.isArray(r4.body) && r4.body.length === 0);
  assert('authenticated: direct /rest/v1/deals blocked (S12)', directBlocked);

  // Test 5: anon cannot call RPCs
  const r5 = await rpcPost('list_deals_v1', { p_limit: 100 }, anonToken);
  const anonBlocked = r5.status === 401 || r5.status === 403 || (r5.body?.ok === false);
  assert('anon: list_deals_v1 denied', anonBlocked);

  console.log('');
  console.log(`# Results: ${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

run().catch(e => { console.error(e); process.exit(1); });
