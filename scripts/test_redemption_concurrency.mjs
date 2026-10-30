/**
 * Script de Concurrencia — Fase 7: Billetera, Tienda y Canjes
 * Usa native `fetch` de Node.js contra la API REST local de Supabase.
 *
 * Test A: 20 llamadas simultáneas de 1 usuario con saldo para 1 solo canje
 *         → exactamente 1 éxito y 19 rechazos
 * Test B: Stock = 1, 5 usuarios distintos intentando canjear al mismo tiempo
 *         → exactamente 1 éxito y 4 rechazos por stock agotado
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
  // Try login first
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

  // Create user via admin API if login failed
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
      user_metadata: { first_name: 'Test', last_name: 'Fan' }
    })
  });
  const _adminUserData = await adminAuthRes.json();

  // Retry sign in
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

async function userRedeemProduct(userToken, productId) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/redeem_product`, {
    method: 'POST',
    headers: {
      'apikey': ANON_KEY,
      'Authorization': `Bearer ${userToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      p_product_id: productId,
      p_idempotency_key: `idemp_${Math.random().toString(36).slice(2)}`,
      p_variant: null
    })
  });
  const data = await res.json();
  return { status: res.status, ok: res.ok, data };
}

async function runConcurrencyTests() {
  console.log('🚀 Iniciando pruebas de concurrencia para Fase 7...\n');

  // Prepare product A for Test A
  console.log('📦 Preparando producto y usuario para Test A (20 llamadas paralelas, 1 solo usuario)...');
  const createdA = await adminQuery('products', {
    method: 'POST',
    headers: { 'Prefer': 'return=representation' },
    body: [{
      team_id: DEFAULT_TEAM_ID,
      name: 'Gorra Concurrencia A ' + Date.now(),
      description: 'Test A',
      cost_pearls: 100,
      stock: 50,
      active: true
    }]
  });
  const productA = createdA[0];

  const userA = await signUpOrSignInUser(`concurrency_user_a_${Date.now()}@guaiqueries.com`);

  // Ensure follow and wallet entry exist for team
  await adminQuery('team_follows', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [{ user_id: userA.user.id, team_id: DEFAULT_TEAM_ID }]
  });

  await adminQuery('wallets', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [{ fan_id: userA.user.id, team_id: DEFAULT_TEAM_ID, balance_cache: 100 }]
  });

  // Credit 100 pearls to userA (enough for exactly 1 redemption)
  await adminQuery('ledger_entries', {
    method: 'POST',
    body: [{
      fan_id: userA.user.id,
      team_id: DEFAULT_TEAM_ID,
      amount: 100,
      type: 'bonus',
      status: 'confirmed',
      note: 'Saldo para Test A concurrencia'
    }]
  });
  // Update wallet cache
  await adminQuery(`wallets?fan_id=eq.${userA.user.id}&team_id=eq.${DEFAULT_TEAM_ID}`, {
    method: 'PATCH',
    body: { balance_cache: 100 }
  });

  console.log(`👤 Usuario A creado: ${userA.user.id} | Saldo: 100 perlitas | Precio producto: ${productA.cost_pearls} | Stock: 50`);
  console.log('🔥 Disparando 20 llamadas simultáneas a `redeem_product`...');

  const callsA = Array.from({ length: 20 }).map(() => userRedeemProduct(userA.token, productA.id));
  const resultsA = await Promise.all(callsA);

  const successA = resultsA.filter(r => r.ok && r.data && (r.data.redemption_id || r.data.id));
  const failureA = resultsA.filter(r => !r.ok || (r.data && r.data.message));

  console.log(`\n📊 RESULTADOS TEST A:`);
  console.log(`   - Total llamadas: ${resultsA.length}`);
  console.log(`   - Muestra de respuesta 0:`, JSON.stringify(resultsA[0]));
  console.log(`   - Canjes exitosos: ${successA.length}`);
  console.log(`   - Rechazos por saldo insuficiente: ${failureA.length}`);

  if (successA.length !== 1) {
    console.error(`❌ TEST A FALLÓ: Se esperaban exactamente 1 canje exitoso, se obtuvieron ${successA.length}`);
    process.exit(1);
  }
  console.log('✅ TEST A PASÓ PERFECTAMENTE: Solo 1 canje exitoso y 19 rechazos concurrentes.');

  // Test B: Stock = 1, 5 usuarios distintos intentando canjear al mismo tiempo
  console.log('\n------------------------------------------------');
  console.log('📦 Preparando producto con STOCK = 1 para Test B (5 usuarios concurrentes)...');

  const createdB = await adminQuery('products', {
    method: 'POST',
    headers: { 'Prefer': 'return=representation' },
    body: [{
      team_id: DEFAULT_TEAM_ID,
      name: 'Camiseta Edición Única Concurrencia B',
      description: 'Test B Stock 1',
      cost_pearls: 50,
      stock: 1,
      active: true
    }]
  });
  const productB = createdB[0];

  const usersB = [];
  for (let i = 1; i <= 5; i++) {
    const u = await signUpOrSignInUser(`concurrency_user_b_${Date.now()}_${i}@guaiqueries.com`);
    await adminQuery('team_follows', {
      method: 'POST',
      headers: { 'Prefer': 'resolution=merge-duplicates' },
      body: [{ user_id: u.user.id, team_id: DEFAULT_TEAM_ID }]
    });
    await adminQuery('wallets', {
      method: 'POST',
      headers: { 'Prefer': 'resolution=merge-duplicates' },
      body: [{ fan_id: u.user.id, team_id: DEFAULT_TEAM_ID, balance_cache: 200 }]
    });
    await adminQuery('ledger_entries', {
      method: 'POST',
      body: [{
        fan_id: u.user.id,
        team_id: DEFAULT_TEAM_ID,
        amount: 200,
        type: 'bonus',
        status: 'confirmed',
        note: 'Saldo Test B'
      }]
    });
    await adminQuery(`wallets?fan_id=eq.${u.user.id}&team_id=eq.${DEFAULT_TEAM_ID}`, {
      method: 'PATCH',
      body: { balance_cache: 200 }
    });
    usersB.push(u);
  }

  console.log(`🔥 Disparando 5 canjes simultáneos de 5 usuarios distintos contra el mismo producto (Stock: 1)...`);
  const callsB = usersB.map(u => userRedeemProduct(u.token, productB.id));
  const resultsB = await Promise.all(callsB);

  const successB = resultsB.filter(r => r.ok && r.data && (r.data.redemption_id || r.data.id));
  const failureB = resultsB.filter(r => !r.ok || (r.data && r.data.message));

  console.log(`\n📊 RESULTADOS TEST B:`);
  console.log(`   - Total llamadas: ${resultsB.length}`);
  console.log(`   - Canjes exitosos: ${successB.length}`);
  console.log(`   - Rechazos por stock: ${failureB.length}`);

  // Inspect stock after test
  const updatedProductB = await adminQuery(`products?id=eq.${productB.id}`);
  const finalStock = updatedProductB[0].stock;
  console.log(`   - Stock final en DB: ${finalStock}`);

  if (successB.length !== 1 || finalStock !== 0) {
    console.error(`❌ TEST B FALLÓ: Se esperaba 1 canje exitoso y stock final 0. Exitosos: ${successB.length}, Stock: ${finalStock}`);
    process.exit(1);
  }

  console.log('✅ TEST B PASÓ PERFECTAMENTE: Exclusividad de stock garantizada (1 éxito, 4 rechazos, stock 0).');
  console.log('\n🎉 TODAS LAS PRUEBAS DE CONCURRENCIA DE LA FASE 7 PASARON EXITOSAMENTE!');
}

runConcurrencyTests().catch(err => {
  console.error('❌ Error fatal en pruebas de concurrencia:', err);
  process.exit(1);
});
