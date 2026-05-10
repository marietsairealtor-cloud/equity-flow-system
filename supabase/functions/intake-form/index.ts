// supabase/functions/intake-form/index.ts
// Build Route 10.12D2 — public intake forms via Edge Function (submit_form_v1 only).
//
// Supabase rewrites GET responses that use Content-Type: text/html to text/plain
// (see https://supabase.com/docs/guides/functions/http-methods — "HTML content is not supported").
// This function therefore returns application/json: { ok: true, html: "..." } so hosts can
// fetch it and assign iframe.srcdoc (or equivalent). Do not use iframe src= pointing directly
// at this URL if you need the form to render as HTML.
//
// Secrets: set SUPABASE_ANON_KEY on the function (Dashboard → Edge Functions → Secrets).
// SUPABASE_URL is provided automatically by Supabase.

const ALLOWED_TYPES = new Set(['seller', 'buyer', 'birddog'])

function corsJsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: new Headers({
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'Access-Control-Allow-Origin': '*',
    }),
  })
}

function corsOptionsResponse(): Response {
  return new Response(null, {
    status: 204,
    headers: new Headers({
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers':
        'authorization, x-client-info, apikey, content-type',
      'Access-Control-Max-Age': '86400',
    }),
  })
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

/** Break-out safe embedding of JSON inside <script type="application/json"> */
function jsonForScriptTag(obj: Record<string, string>): string {
  return JSON.stringify(obj).replace(/</g, '\\u003c')
}

function fieldBlock(
  id: string,
  label: string,
  inputAttrs: string,
  required: boolean,
): string {
  const req = required ? ' <span style="color:#666">*</span>' : ''
  return `<div class="intake-field">
  <label for="${escapeHtml(id)}">${escapeHtml(label)}${req}</label>
  <input id="${escapeHtml(id)}" name="${escapeHtml(id)}" ${inputAttrs}/>
</div>`
}

function textareaBlock(id: string, label: string, required: boolean): string {
  const req = required ? ' <span style="color:#666">*</span>' : ''
  return `<div class="intake-field">
  <label for="${escapeHtml(id)}">${escapeHtml(label)}${req}</label>
  <textarea id="${escapeHtml(id)}" name="${escapeHtml(id)}" rows="3"></textarea>
</div>`
}

function formFields(type: string): string {
  const hiddenSpam =
    `<input type="hidden" id="spam_token" name="spam_token" value=""/>`

  if (type === 'seller') {
    return (
      hiddenSpam +
      fieldBlock('address', 'Address', 'type="text" autocomplete="street-address" required', true) +
      fieldBlock('name', 'Name', 'type="text" autocomplete="name" required', true) +
      fieldBlock('phone', 'Phone', 'type="tel" autocomplete="tel" required', true) +
      fieldBlock('email', 'Email', 'type="email" autocomplete="email" required', true)
    )
  }

  if (type === 'buyer') {
    return (
      hiddenSpam +
      fieldBlock('name', 'Name', 'type="text" autocomplete="name" required', true) +
      fieldBlock('email', 'Email', 'type="email" autocomplete="email" required', true) +
      fieldBlock('phone', 'Phone', 'type="tel" autocomplete="tel" required', true) +
      fieldBlock('areas_of_interest', 'Areas of interest', 'type="text" autocomplete="off"', false) +
      fieldBlock('budget_range', 'Budget range', 'type="text" autocomplete="off"', false)
    )
  }

  // birddog
  return (
    hiddenSpam +
    fieldBlock('address', 'Address', 'type="text" autocomplete="street-address" required', true) +
    fieldBlock('name', 'Name', 'type="text" autocomplete="name" required', true) +
    fieldBlock('phone', 'Phone', 'type="tel" autocomplete="tel" required', true) +
    fieldBlock('email', 'Email', 'type="email" autocomplete="email" required', true) +
    textareaBlock('condition_notes', 'Condition notes', false) +
    fieldBlock('asking_price', 'Asking price', 'type="text" autocomplete="off"', false)
  )
}

function intakePageHtml(opts: {
  slug: string
  type: string
  supabaseUrl: string
  anonKey: string
}): string {
  const cfgJson = jsonForScriptTag({
    supabaseUrl: opts.supabaseUrl,
    anonKey: opts.anonKey,
    slug: opts.slug,
    type: opts.type,
  })

  const fields = formFields(opts.type)

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Contact form</title>
  <style>
    #intake-embed-root * { box-sizing: border-box; }
    #intake-embed-root {
      font-family: system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif;
      background: #fff;
      color: #111;
      padding: 1rem;
      margin: 0 auto;
      max-width: 28rem;
      line-height: 1.45;
      font-size: 16px;
      -webkit-text-size-adjust: 100%;
    }
    #intake-embed-root .intake-field { margin-bottom: 0.85rem; }
    #intake-embed-root label {
      display: block;
      font-size: 0.8125rem;
      font-weight: 500;
      margin-bottom: 0.28rem;
      color: #333;
    }
    #intake-embed-root input[type="text"],
    #intake-embed-root input[type="email"],
    #intake-embed-root input[type="tel"],
    #intake-embed-root textarea {
      width: 100%;
      padding: 0.5rem 0.6rem;
      border: 1px solid #ccc;
      border-radius: 4px;
      font: inherit;
      background: #fff;
      color: #111;
    }
    #intake-embed-root textarea { resize: vertical; min-height: 4.5rem; }
    #intake-embed-root button[type="submit"] {
      width: 100%;
      margin-top: 0.35rem;
      padding: 0.65rem 1rem;
      font: inherit;
      font-weight: 600;
      color: #fff;
      background: #222;
      border: none;
      border-radius: 4px;
      cursor: pointer;
    }
    #intake-embed-root button[type="submit"]:disabled {
      opacity: 0.55;
      cursor: not-allowed;
    }
    #intake-embed-root #intake-status {
      margin-top: 0.75rem;
      font-size: 0.875rem;
      min-height: 1.25rem;
      color: #b00020;
    }
    #intake-embed-root #intake-success {
      font-size: 1rem;
      color: #333;
      padding: 0.5rem 0;
      display: none;
    }
  </style>
</head>
<body>
  <div id="intake-embed-root">
    <form id="intake-form" novalidate>
      ${fields}
      <button type="submit" id="intake-submit">Submit</button>
      <div id="intake-status" aria-live="polite"></div>
    </form>
    <div id="intake-success">Thank you. We'll be in touch.</div>
  </div>
  <script type="application/json" id="intake-config">${cfgJson}</script>
  <script>
(function () {
  var cfg;
  try {
    cfg = JSON.parse(document.getElementById('intake-config').textContent);
  } catch (e) {
    return;
  }

  var form = document.getElementById('intake-form');
  var btn = document.getElementById('intake-submit');
  var statusEl = document.getElementById('intake-status');
  var successEl = document.getElementById('intake-success');
  var spamEl = document.getElementById('spam_token');

  if (!form || !btn || !spamEl) return;

  try {
    spamEl.value = typeof crypto !== 'undefined' && crypto.randomUUID
      ? crypto.randomUUID()
      : String(Date.now()) + '-' + Math.random().toString(36).slice(2);
  } catch (_) {
    spamEl.value = String(Date.now());
  }

  var flight = false;
  var doneSuccess = false;

  function setStatus(msg, isError) {
    statusEl.textContent = msg || '';
    statusEl.style.color = isError ? '#b00020' : '#333';
  }

  function val(id) {
    var el = document.getElementById(id);
    return el && el.value ? String(el.value).trim() : '';
  }

  form.addEventListener('submit', async function (ev) {
    ev.preventDefault();
    if (doneSuccess || flight) return;

    setStatus('', false);
    flight = true;
    btn.disabled = true;
    btn.textContent = 'Submitting...';

    var payload;
    var type = cfg.type;

    try {
      if (type === 'seller') {
        payload = {
          address: val('address'),
          name: val('name'),
          phone: val('phone'),
          email: val('email'),
          spam_token: spamEl.value,
        };
        if (!payload.address || !payload.name || !payload.phone || !payload.email) {
          throw new Error('Please fill in all required fields.');
        }
      } else if (type === 'buyer') {
        payload = {
          name: val('name'),
          email: val('email'),
          phone: val('phone'),
          spam_token: spamEl.value,
        };
        var ai = val('areas_of_interest');
        var br = val('budget_range');
        if (ai) payload.areas_of_interest = ai;
        if (br) payload.budget_range = br;
        if (!payload.name || !payload.email || !payload.phone) {
          throw new Error('Please fill in all required fields.');
        }
      } else {
        payload = {
          address: val('address'),
          name: val('name'),
          phone: val('phone'),
          email: val('email'),
          spam_token: spamEl.value,
        };
        var cn = val('condition_notes');
        var ap = val('asking_price');
        if (cn) payload.condition_notes = cn;
        if (ap) payload.asking_price = ap;
        if (!payload.address || !payload.name || !payload.phone || !payload.email) {
          throw new Error('Please fill in all required fields.');
        }
      }

      var base = cfg.supabaseUrl;
      if (base.charAt(base.length - 1) === '/') base = base.slice(0, -1);
      var rpcUrl = base + '/rest/v1/rpc/submit_form_v1';
      var res = await fetch(rpcUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': cfg.anonKey,
          'Authorization': 'Bearer ' + cfg.anonKey,
        },
        body: JSON.stringify({
          p_slug: cfg.slug,
          p_form_type: cfg.type,
          p_payload: payload,
        }),
      });

      var bodyText = await res.text();
      var data;
      try {
        data = bodyText ? JSON.parse(bodyText) : {};
      } catch (_) {
        throw new Error('network');
      }

      if (!res.ok && data && typeof data === 'object' && !('ok' in data) && !data.code) {
        throw new Error('network');
      }

      var ok = data.ok === true || data.ok === 'true';
      if (ok) {
        doneSuccess = true;
        form.style.display = 'none';
        successEl.style.display = 'block';
        return;
      }

      var code = data.code || '';
      var msg = data.message || '';

      if (code === 'NOT_AUTHORIZED') {
        setStatus('This form is not currently accepting submissions.', true);
      } else if (code === 'VALIDATION_ERROR') {
        setStatus(msg || 'Invalid submission.', true);
      } else if (code === 'NOT_FOUND') {
        setStatus('Form not found.', true);
      } else {
        setStatus(msg || 'Something went wrong. Please try again.', true);
      }
    } catch (err) {
      if (err && err.message === 'network') {
        setStatus('Something went wrong. Please try again.', true);
      } else if (err && err.message) {
        setStatus(err.message, true);
      } else {
        setStatus('Something went wrong. Please try again.', true);
      }
    } finally {
      flight = false;
      if (!doneSuccess) {
        btn.disabled = false;
        btn.textContent = 'Submit';
      }
    }
  });
})();
  </script>
</body>
</html>`
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return corsOptionsResponse()
  }

  if (req.method !== 'GET') {
    return corsJsonResponse(
      { ok: false, error: 'Method not allowed.', code: 'METHOD_NOT_ALLOWED' },
      405,
    )
  }

  let url: URL
  try {
    url = new URL(req.url)
  } catch {
    return corsJsonResponse(
      { ok: false, error: 'Bad request.', code: 'BAD_REQUEST' },
      400,
    )
  }

  const slug = (url.searchParams.get('slug') ?? '').trim()
  const typeRaw = (url.searchParams.get('type') ?? '').trim().toLowerCase()

  if (!slug) {
    return corsJsonResponse(
      { ok: false, error: 'Missing slug.', code: 'MISSING_SLUG' },
      400,
    )
  }

  if (!ALLOWED_TYPES.has(typeRaw)) {
    return corsJsonResponse(
      { ok: false, error: 'Invalid form type.', code: 'INVALID_TYPE' },
      400,
    )
  }

  const type = typeRaw as 'seller' | 'buyer' | 'birddog'

  const supabaseUrl = Deno.env.get('SUPABASE_URL')?.trim()
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')?.trim()

  if (!supabaseUrl || !anonKey) {
    console.error('intake-form: missing SUPABASE_URL or SUPABASE_ANON_KEY')
    return corsJsonResponse(
      { ok: false, error: 'Server configuration error.', code: 'SERVER_CONFIG' },
      500,
    )
  }

  const html = intakePageHtml({ slug, type, supabaseUrl, anonKey })

  return corsJsonResponse({ ok: true, html }, 200)
})
