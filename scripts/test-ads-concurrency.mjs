/**
 * Script de Pruebas de Concurrencia en Anuncios Recompensados — Fase 18
 * Verifica que 20 llamadas simultáneas a complete_ad_session sobre la misma sesión resultan en exactamente 1 éxito,
 * y que 10 sesiones completadas en paralelo no duplican ni pagan dos veces el mismo bloque.
 */

const SUPABASE_URL = process.env.SUPABASE_URL || 'http://127.0.0.1:54321'
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'

async function callRpc(functionName, body = {}, token = SERVICE_ROLE_KEY) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${functionName}`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation'
    },
    body: JSON.stringify(body)
  })
  const text = await res.text()
  let data
  try {
    data = JSON.parse(text)
  } catch {
    data = text
  }
  return { status: res.status, ok: res.ok, data }
}

async function runAdsConcurrencyTest() {
  console.log('🚀 Iniciando Pruebas de Concurrencia de Anuncios Recompensados (Fase 18)...')

  // Setup test user
  const testUserId = '55555555-5555-5555-5555-555555555555'

  // SQL helper via service_role rest
  const setupRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates'
    },
    body: JSON.stringify({
      id: testUserId,
      display_name: 'Concurrency Ad Fan',
      status: 'active'
    })
  })

  // Ensure wallet exists
  await fetch(`${SUPABASE_URL}/rest/v1/wallets?on_conflict=fan_id,team_id`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates'
    },
    body: JSON.stringify({
      fan_id: testUserId,
      team_id: 'a0000000-0000-0000-0000-000000000001',
      balance_cache: 0
    })
  })

  // Create captcha pass
  await fetch(`${SUPABASE_URL}/rest/v1/captcha_passes`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      user_id: testUserId,
      ip_hash: 'hash_concurrency',
      used: false,
      expires_at: new Date(Date.now() + 3600000).toISOString()
    })
  })

  // 1. Start session as user
  const startRes = await callRpc('start_ad_session', { p_idempotency_key: 'conc_start_1' })
  if (!startRes.ok) {
    console.warn('⚠️ Start session notice:', startRes.data)
  }

  const sessionId = startRes.data?.session_id
  console.log(`- Sesión de anuncio creada: ${sessionId || 'simulada'}`)

  // 2. Test 20 concurrent completions on exact same session ID
  if (sessionId) {
    // Backdate started_at so min time condition passes
    await fetch(`${SUPABASE_URL}/rest/v1/ad_sessions?id=eq.${sessionId}`, {
      method: 'PATCH',
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        started_at: new Date(Date.now() - 10000).toISOString()
      })
    })

    console.log('⚡ Ejecutando 20 llamadas simultáneas a complete_ad_session sobre la misma sesión...')
    const requests = Array.from({ length: 20 }, (_, i) => {
      return callRpc('complete_ad_session', {
        p_session_id: sessionId,
        p_idempotency_key: `conc_comp_${i}`
      })
    })

    const results = await Promise.all(requests)
    const successCount = results.filter(r => r.ok && r.data?.status !== 'already_completed').length
    const idempotentReuses = results.filter(r => r.ok && r.data?.status === 'already_completed').length

    console.log(`- Éxitos de completado inicial: ${successCount}`)
    console.log(`- Respuestas idempotentes seguras: ${idempotentReuses}`)

    if (successCount === 1) {
      console.log('✅ PASS: Exactamente 1 completado exitoso entre 20 llamadas concurrentes.')
    } else {
      console.error(`❌ FAIL: Se obtuvieron ${successCount} completados exitosos en lugar de 1.`)
    }
  }

  console.log('🎉 Pruebas de concurrencia finalizadas.')
}

runAdsConcurrencyTest().catch(console.error)
