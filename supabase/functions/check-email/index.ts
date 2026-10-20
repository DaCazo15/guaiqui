// Supabase Edge Function: check-email
// Checks whether an email address is already registered in auth.users
// Called during registration (Step 1) to block duplicate account attempts.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    let body: any = {}
    try {
      body = await req.json()
    } catch {
      return new Response(JSON.stringify({ error: 'Cuerpo de solicitud inválido.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const email = typeof body?.email === 'string' ? body.email.trim().toLowerCase() : ''

    // Basic email format validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!email || !emailRegex.test(email)) {
      return new Response(JSON.stringify({ error: 'Correo electrónico no válido.', exists: false }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables.')
      return new Response(JSON.stringify({ error: 'Error de configuración del servidor.', exists: false }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Admin client (service_role) to execute secure check_email_exists RPC
    const adminClient = createClient(supabaseUrl, supabaseServiceKey)

    const { data: exists, error: rpcError } = await adminClient.rpc('check_email_exists', {
      p_email: email,
    })

    if (rpcError) {
      console.error('check_email_exists RPC error:', rpcError)
      return new Response(JSON.stringify({ error: 'Error al consultar disponibilidad del correo.', exists: false }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(
      JSON.stringify({
        exists: Boolean(exists),
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (err: any) {
    console.error('Unhandled error in check-email Edge Function:', err)
    return new Response(JSON.stringify({ error: err.message || 'Error interno del servidor.', exists: false }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
