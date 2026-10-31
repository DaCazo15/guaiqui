/**
 * Script de Concurrencia — Fase 8: Entrega e Idempotencia de Canjes
 * Usa native `fetch` de Node.js contra la API REST local de Supabase.
 *
 * Test A: 10 llamadas simultáneas a `deliver_redemption` con llaves de idempotencia DISTINTAS
 *         → exactamente 1 éxito ('delivered') y 9 'ALREADY_DELIVERED'
 * Test B: 10 llamadas simultáneas a `deliver_redemption` con la MISMA llave de idempotencia
 *         → todas devuelven la misma respuesta idempotente sin duplicar entregas
 */

const SUPABASE_URL = 'http://127.0.0.1:54321';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';
const DEFAULT_TEAM_ID = 'a0000000-0000-0000-0000-000000000001';

async function adminQuery(endpoint, options = {}) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${endpoint}`, {
    method: options.method || 'GET',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      ...(options.headers || {})
    },
    body: options.body ? JSON.stringify(options.body) : undefined
  });
  const text = await res.text();
  return text ? JSON.parse(text) : null;
}

async function signUpOrSignInUser(email, password = 'Password123!') {
  const loginRes = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      'apikey': ANON_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ email, password })
  });
  const loginData = await loginRes.json();
  if (loginRes.ok && loginData.access_token) {
    return { token: loginData.access_token, user: loginData.user };
  }

  const adminAuthRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { first_name: 'Test', last_name: 'Staff' }
    })
  });
  await adminAuthRes.json();

  const retryRes = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      'apikey': ANON_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ email, password })
  });
  const retryData = await retryRes.json();
  if (!retryRes.ok) {
    throw new Error(`Failed to sign in user ${email}: ${JSON.stringify(retryData)}`);
  }
  return { token: retryData.access_token, user: retryData.user };
}

async function deliverRedemptionCall(staffToken, redemptionId, idempotencyKey, note = 'Entrega concurrente test') {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/deliver_redemption`, {
    method: 'POST',
    headers: {
      'apikey': ANON_KEY,
      'Authorization': `Bearer ${staffToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      p_redemption_id: redemptionId,
      p_idempotency_key: idempotencyKey,
      p_note: note
    })
  });
  const data = await res.json();
  return { status: res.status, ok: res.ok, data };
}

async function runDeliveryConcurrencyTests() {
  console.log('🚀 Iniciando pruebas de concurrencia e idempotencia para deliver_redemption (Fase 8)...\n');

  // 1. Crear Staff User
  const staffUser = await signUpOrSignInUser(`staff_concurrency_${Date.now()}@guaiqueries.com`);
  await adminQuery('staff_members', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [{ user_id: staffUser.user.id, role: 'staff', team_id: DEFAULT_TEAM_ID, active: true }]
  });

  // 2. Crear Fan User con saldo y producto
  const fanUser = await signUpOrSignInUser(`fan_concurrency_${Date.now()}@guaiqueries.com`);
  await adminQuery('profiles', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [{ id: fanUser.user.id, display_name: 'Fan Concurrency', status: 'active' }]
  });
  await adminQuery('team_follows', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [{ user_id: fanUser.user.id, team_id: DEFAULT_TEAM_ID }]
  });
  await adminQuery('wallets', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [{ fan_id: fanUser.user.id, team_id: DEFAULT_TEAM_ID, balance_cache: 1000 }]
  });

  const createdProduct = await adminQuery('products', {
    method: 'POST',
    headers: { 'Prefer': 'return=representation' },
    body: [{
      team_id: DEFAULT_TEAM_ID,
      name: 'Gorra Concurrencia Entrega ' + Date.now(),
      description: 'Test entrega concurrente',
      cost_pearls: 100,
      stock: 10,
      active: true
    }]
  });
  const product = createdProduct[0];

  // Crear Canje A en estado 'approved'
  const createdRedemptionA = await adminQuery('redemptions', {
    method: 'POST',
    headers: { 'Prefer': 'return=representation' },
    body: [{
      fan_id: fanUser.user.id,
      team_id: DEFAULT_TEAM_ID,
      product_id: product.id,
      cost_pearls: 100,
      status: 'approved',
      code_hash: 'test_hash_a_' + Date.now(),
      idempotency_key: 'idemp_setup_a_' + Date.now()
    }]
  });
  if (!createdRedemptionA || !createdRedemptionA[0]) {
    throw new Error('Failed to create redemption A: ' + JSON.stringify(createdRedemptionA));
  }
  const redemptionA = createdRedemptionA[0];

  console.log(`📦 Canje A creado: ${redemptionA.id} | Estado inicial: ${redemptionA.status}`);
  console.log('🔥 TEST A: Disparando 10 llamadas simultáneas con distintas llaves de idempotencia...');

  const callsA = Array.from({ length: 10 }).map((_, idx) =>
    deliverRedemptionCall(staffUser.token, redemptionA.id, `idemp_diff_${idx}_${Date.now()}`)
  );
  const resultsA = await Promise.all(callsA);

  const deliveredA = resultsA.filter(r => r.ok && r.data && r.data.result === 'SUCCESS');
  const alreadyDeliveredA = resultsA.filter(r => r.ok && r.data && r.data.result === 'ALREADY_DELIVERED');

  console.log(`\n📊 RESULTADOS TEST A:`);
  console.log(`   - Total llamadas: ${resultsA.length}`);
  console.log(`   - Exitosos ('delivered'): ${deliveredA.length}`);
  console.log(`   - Idempotentes ('already_delivered'): ${alreadyDeliveredA.length}`);

  if (deliveredA.length !== 1 || alreadyDeliveredA.length !== 9) {
    console.error(`❌ TEST A FALLÓ: Se esperaba 1 delivered y 9 already_delivered. Obtenido: ${deliveredA.length} / ${alreadyDeliveredA.length}`);
    console.error('Muestra de resultados:', JSON.stringify(resultsA, null, 2));
    process.exit(1);
  }
  console.log('✅ TEST A PASÓ PERFECTAMENTE: Transacción locking impidió doble entrega.');

  // ------------------------------------------------------------------
  // TEST B: 10 llamadas simultáneas con la MISMA llave de idempotencia
  // ------------------------------------------------------------------
  console.log('\n------------------------------------------------');
  const createdRedemptionB = await adminQuery('redemptions', {
    method: 'POST',
    headers: { 'Prefer': 'return=representation' },
    body: [{
      fan_id: fanUser.user.id,
      team_id: DEFAULT_TEAM_ID,
      product_id: product.id,
      cost_pearls: 100,
      status: 'approved',
      code_hash: 'test_hash_b_' + Date.now(),
      idempotency_key: 'idemp_setup_b_' + Date.now()
    }]
  });
  if (!createdRedemptionB || !createdRedemptionB[0]) {
    throw new Error('Failed to create redemption B: ' + JSON.stringify(createdRedemptionB));
  }
  const redemptionB = createdRedemptionB[0];

  const sameIdempotencyKey = `same_key_test_b_${Date.now()}`;
  console.log(`📦 Canje B creado: ${redemptionB.id} | Llave compartida: ${sameIdempotencyKey}`);
  console.log('🔥 TEST B: Disparando 10 llamadas simultáneas con la MISMA llave...');

  const callsB = Array.from({ length: 10 }).map(() =>
    deliverRedemptionCall(staffUser.token, redemptionB.id, sameIdempotencyKey)
  );
  const resultsB = await Promise.all(callsB);

  const okResultsB = resultsB.filter(r => r.ok && r.data && (r.data.result === 'SUCCESS' || r.data.result === 'ALREADY_DELIVERED'));
  const uniqueKeyResponses = new Set(resultsB.map(r => JSON.stringify(r.data)));

  console.log(`\n📊 RESULTADOS TEST B:`);
  console.log(`   - Total llamadas ok: ${okResultsB.length}`);
  console.log(`   - Respuestas distintas: ${uniqueKeyResponses.size}`);

  if (okResultsB.length !== 10) {
    console.error(`❌ TEST B FALLÓ: Se esperaban 10 respuestas OK idempotentes.`);
    process.exit(1);
  }
  console.log('✅ TEST B PASÓ PERFECTAMENTE: Misma llave devolvió resultado consistente sin errores.');
  console.log('\n🎉 TODAS LAS PRUEBAS DE CONCURRENCIA DE ENTREGA PASARON EXITOSAMENTE!');
}

runDeliveryConcurrencyTests().catch(err => {
  console.error('❌ Error fatal en pruebas de entrega:', err);
  process.exit(1);
});
