import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  try {
    const payload = await req.json()
    const record = payload.record

    if (!record?.invited_email) {
      return new Response('no email', { status: 200 })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { error } = await supabase.auth.admin.inviteUserByEmail(
      record.invited_email
    )

    if (error) {
      console.error('invite email failed:', error.message)
      // fail silently — invite row already exists
    }

    return new Response('ok', { status: 200 })
  } catch (err) {
    console.error('edge function error:', err)
    return new Response('error', { status: 200 })
  }
})