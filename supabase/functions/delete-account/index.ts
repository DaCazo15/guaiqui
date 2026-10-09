// Supabase Edge Function: delete-account
// Handles account deletion idempotently:
// 1. Validates user JWT and extracts caller ID
// 2. Calls delete_my_account RPC (which checks pending redemptions & held pearls, anonymizes profile)
// 3. Admin client bans user in auth.users permanently and replaces email with an un-reusable anonymous email (e.g. deleted_xxx@deleted.guaiqui.invalid)
// 4. Invokes secure RPC purge_auth_identities(userId) via service role to delete OAuth provider metadata
// 5. Cleans up avatar files from Storage bucket

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
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'No se proporcionó token de autenticación.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    // 1. User client (verifies JWT signature and extracts authenticated caller user)
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: { user }, error: userError } = await userClient.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Usuario no autenticado o sesión expirada.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const userId = user.id

    // 2. Call RPC delete_my_account() (Strictly uses auth.uid() inside database - no user_id parameter accepted)
    const { data: rpcResult, error: rpcError } = await userClient.rpc('delete_my_account')
    if (rpcError) {
      return new Response(JSON.stringify({ error: rpcError.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 3. Admin client (service role) for banning user & anonymizing email in auth.users
    const adminClient = createClient(supabaseUrl, supabaseServiceKey)

    // Remove avatar files from storage if present
    try {
      const { data: files } = await adminClient.storage.from('avatars').list(userId)
      if (files && files.length > 0) {
        const filePaths = files.map(f => `${userId}/${f.name}`)
        await adminClient.storage.from('avatars').remove(filePaths)
      }
    } catch (stErr) {
      console.warn('Storage cleanup warning:', stErr)
    }

    // Permanent BAN & anonymize email in auth.users
    const anonEmail = `deleted_${userId.replace(/-/g, '')}@deleted.guaiqui.invalid`
    
    const { error: banErr } = await adminClient.auth.admin.updateUserById(userId, {
      email: anonEmail,
      email_confirm: true,
      ban_duration: '876000h', // 100 years ban
      user_metadata: {},
      app_metadata: { provider: 'email', providers: ['email'] },
    })

    if (banErr) {
      console.warn('Admin ban warning:', banErr)
    }

    // Revoke all active sessions and refresh tokens globally
    try {
      await adminClient.auth.admin.signOut(userId, 'global')
    } catch (soErr) {
      console.warn('Admin signOut warning:', soErr)
    }

    // Delete provider OAuth identity metadata securely via purge_auth_identities RPC (service_role only)
    try {
      await adminClient.rpc('purge_auth_identities', { p_user_id: userId })
    } catch (idErr) {
      console.warn('Identities cleanup warning:', idErr)
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Tu cuenta ha sido deshabilitada y anonimizada permanentemente.',
        details: rpcResult,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || 'Error interno al procesar eliminación.' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
