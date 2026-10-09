import { test, expect } from '@playwright/test'

const ADMIN_URL = 'http://localhost:3011'
const SUPABASE_URL = 'http://127.0.0.1:54321'
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'

async function adminQuery(endpoint: string, options: any = {}) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${endpoint}`, {
    method: options.method || 'GET',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      ...(options.headers || {})
    },
    body: options.body ? JSON.stringify(options.body) : undefined
  })
  const text = await res.text()
  return text ? JSON.parse(text) : null
}

async function signUpOrSignInUser(email: string, password = 'Password123!') {
  const loginRes = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      'apikey': ANON_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ email, password })
  })
  const loginData = await loginRes.json()
  if (loginRes.ok && loginData.access_token) {
    return { token: loginData.access_token, user: loginData.user }
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
      user_metadata: { first_name: 'Test', last_name: 'User', terms_accepted: true }
    })
  })
  await adminAuthRes.json()

  const retryRes = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      'apikey': ANON_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ email, password })
  })
  const retryData = await retryRes.json()
  return { token: retryData.access_token, user: retryData.user }
}

async function setupAdminE2EUsers() {
  const time = Date.now()
  const adminEmail = `admin_e2e_f11_${time}@guaiqui.test`
  const fanEmail = `fan_e2e_f11_${time}@guaiqui.test`

  const adminUser = await signUpOrSignInUser(adminEmail)
  const fanUser = await signUpOrSignInUser(fanEmail)
  const nowIso = new Date().toISOString()

  await adminQuery('profiles', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [
      { id: adminUser.user.id, display_name: 'Admin E2E F11', status: 'active', terms_accepted_at: nowIso, privacy_accepted_at: nowIso, pearls_rules_accepted_at: nowIso },
      { id: fanUser.user.id, display_name: 'Fan Suspect E2E', status: 'active', terms_accepted_at: nowIso, privacy_accepted_at: nowIso, pearls_rules_accepted_at: nowIso }
    ]
  })

  await adminQuery('staff_members', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [
      { user_id: adminUser.user.id, role: 'admin', active: true }
    ]
  })

  // Insert test risk flag and held ledger entry
  await adminQuery('risk_flags', {
    method: 'POST',
    body: [
      { fan_id: fanUser.user.id, reason: 'Implausible trivia completion speed (1.2s)', severity: 'high', resolved: false }
    ]
  })

  await adminQuery('ledger_entries', {
    method: 'POST',
    body: [
      { fan_id: fanUser.user.id, amount: 200, type: 'trivia_reward', status: 'held', source_type: 'trivia_attempt', source_id: `att_${time}`, note: 'Retenido por prueba E2E' }
    ]
  })

  return { adminEmail, fanEmail }
}

test.describe('Fase 11: Antifraude & Cola de Control de Riesgo (apps/admin)', () => {
  let credentials: { adminEmail: string; fanEmail: string }

  test.beforeAll(async () => {
    credentials = await setupAdminE2EUsers()
  })

  test.beforeEach(async ({ page, context }) => {
    await context.clearCookies()
  })

  test('Administrador ve la cola de riesgos y puede liberar perlitas retenidas', async ({ page }) => {
    await page.goto(`${ADMIN_URL}/login`)
    await page.evaluate(() => localStorage.clear())

    await page.fill('input[type="email"]', credentials.adminEmail)
    await page.fill('input[type="password"]', 'Password123!')
    await page.click('button[type="submit"]')

    await page.waitForURL('**/admin/dashboard')
    await page.click('text=Control Riesgo')
    await page.waitForURL('**/admin/riesgo')

    await expect(page.locator('h1')).toContainText('Cola de Revisión Antifraude')
    await expect(page.locator('td:has-text("Fan Suspect E2E")')).toBeVisible({ timeout: 10000 })

    await page.click('button:has-text("Liberar"):first-child')
    await expect(page.locator('h3:has-text("Liberar Perlitas Retenidas")')).toBeVisible()

    await page.fill('textarea[placeholder*="Indica el motivo"]', 'Verificado y aprobado manualmente en prueba E2E')
    await page.click('button:has-text("Confirmar Acción")')

    await expect(page.locator('text=Perlitas liberadas correctamente')).toBeVisible({ timeout: 10000 })
  })
})
