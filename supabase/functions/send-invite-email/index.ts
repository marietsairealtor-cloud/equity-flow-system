import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const APP_URL = Deno.env.get('APP_URL') ?? ''

Deno.serve(async (req) => {
  try {
    const payload = await req.json()
    const record = payload.record

    if (!record?.invited_email) {
      console.log('No invited_email in payload')
      return new Response('no email', { status: 200 })
    }

    const email = record.invited_email.trim().toLowerCase()

    // Guard: APP_URL must be configured
    if (!APP_URL) {
      console.error('APP_URL not configured')
      return new Response('misconfigured', { status: 200 })
    }

    // Check if user exists via DB helper — deterministic, O(1)
    const { data: userExists, error: existsError } = await supabase
      .rpc('auth_user_exists_v1', { p_email: email })

    if (existsError) {
      console.error('auth_user_exists_v1 error:', existsError.message)
      return new Response('lookup error', { status: 200 })
    }

    if (!userExists) {
      // New user — standard Supabase invite flow
      console.log('New user — sending invite email:', email)
      const { error } = await supabase.auth.admin.inviteUserByEmail(email, {
        redirectTo: `${APP_URL}/auth`
      })
      if (error) {
        console.error('inviteUserByEmail error:', error.message)
      }
    } else {
      // Existing user — send OTP magic link via Magic Link template
      console.log('Existing user — sending OTP email:', email)
      const { error } = await supabase.auth.signInWithOtp({
        email,
        options: {
          shouldCreateUser: false,
          emailRedirectTo: `${APP_URL}/auth`
        }
      })
      if (error) {
        console.error('signInWithOtp error:', error.message)
      }
    }

    return new Response('ok', { status: 200 })

  } catch (err) {
    console.error('Edge function error:', err)
    return new Response('error', { status: 200 })
  }
})