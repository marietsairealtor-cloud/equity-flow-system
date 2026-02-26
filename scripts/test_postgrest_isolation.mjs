// scripts/test_postgrest_isolation.mjs
// 6.3 — PostgREST FK embedding + cross-tenant HTTP isolation tests
import { createRequire } from 'module';
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

const serviceToken = jwt.sign(
  { role: 'service_role', iss: 'supabase', aud: 'authenticated' },
  JWT_SECRET,
  { expiresIn: '1h' }
);

const anonToken = jwt.sign(
  { role: 'anon', iss: 'supabase', aud: 'authenticated' },
  JWT_SECRET,
  { expiresIn: '1h' }
);

async function seed() {
  const rows = [
    { id: 'a2000000-0000-0000-0000-000000000001', tenant_id: TENANT_A, row_version: 1, calc_version: 1 },
    { id: 'a2000000-0000-0000-0000-000000000002', tenant_id: TENANT_A, row_version: 1, calc_version: 1 },
    { id: 'b2000000-0000-0000-0000-000000000001', tenant_id: TENANT_B, row_version: 1, calc_version: 1 },
    { id: 'b2000000-0000-0000-0000-000000000002', tenant_id: TENANT_B, row_version: 1, calc_version: 1 },
  ];
  const res = await fetch(`${API_URL}/rest/v1/deals`, {
    method: 'POST',
    headers: {
      'apikey': serviceToken,
      'Authorization': `Bearer ${serviceToken}`,
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates',
    },
    body: JSON.stringify(rows),
  });
  if (!res.ok) {
    const txt = await res.text();
    console.error(`Seed failed: ${res.status} ${txt}`);
    process.exit(1);
  }
  console.log('# Seeded 4 rows (2 per tenant)');
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
  console.log('# PostgREST Tenant Isolation HTTP Tests');
  console.log(`# API: ${API_URL}`);
  console.log('');

  await seed();
  console.log('');

  const tokenA = mintJwt(TENANT_A, 'authenticated');
  const tokenB = mintJwt(TENANT_B, 'authenticated');

  // Test 1: Tenant A reads deals — sees only own
  const r1 = await httpGet('deals?select=*', tokenA);
  assert('Tenant A: HTTP GET deals returns 200', r1.status === 200);
  const allOwnA = Array.isArray(r1.body) && r1.body.every(r => r.tenant_id === TENANT_A);
  assert('Tenant A: all returned deals belong to Tenant A', allOwnA);
  assert('Tenant A: sees >= 2 own deals', Array.isArray(r1.body) && r1.body.length >= 2);

  // Test 2: Tenant A cannot see Tenant B via filter
  const r2 = await httpGet(`deals?select=*&tenant_id=eq.${TENANT_B}`, tokenA);
  assert('Tenant A: filter by Tenant B returns empty', Array.isArray(r2.body) && r2.body.length === 0);

  // Test 3: Tenant B reads deals — sees only own
  const r3 = await httpGet('deals?select=*', tokenB);
  assert('Tenant B: HTTP GET deals returns 200', r3.status === 200);
  const allOwnB = Array.isArray(r3.body) && r3.body.every(r => r.tenant_id === TENANT_B);
  assert('Tenant B: all returned deals belong to Tenant B', allOwnB);

  // Test 4: FK embedding — deals?select=*,tenants(*)
  const r4 = await httpGet('deals?select=*,tenants(*)', tokenA);
  assert('Tenant A: FK embedding does not return 500', r4.status !== 500);
  if (r4.status === 200 && Array.isArray(r4.body)) {
    const fkLeak = r4.body.some(r => r.tenant_id !== TENANT_A);
    assert('Tenant A: FK embedding does not leak Tenant B rows', !fkLeak);
  } else {
    assert('Tenant A: FK embedding blocked or no relationship (safe)', r4.status === 400 || r4.status === 300);
  }

  // Test 5: anon cannot access deals
  const r5 = await httpGet('deals?select=*', anonToken);
  const anonBlocked = r5.status === 401 || r5.status === 403 || (r5.status === 200 && Array.isArray(r5.body) && r5.body.length === 0);
  assert('anon: cannot access deals data', anonBlocked);

  console.log('');
  console.log(`# Results: ${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

run().catch(e => { console.error(e); process.exit(1); });
