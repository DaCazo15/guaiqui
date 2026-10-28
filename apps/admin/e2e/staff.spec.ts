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

async function setupE2EUsers() {
  const time = Date.now()
  const fanEmail = `fan_e2e_f8_${time}@guaiqui.test`
  const staffEmail = `staff_e2e_f8_${time}@guaiqui.test`

  // 1. Fan User
  const fan = await signUpOrSignInUser(fanEmail)

  // 2. Staff User
  const staff = await signUpOrSignInUser(staffEmail)

  const nowIso = new Date().toISOString()

  // Seed profiles with terms accepted timestamps
  await adminQuery('profiles', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [
      {
        id: fan.user.id,
        display_name: 'Fan E2E',
        status: 'active',
        terms_accepted_at: nowIso,
        privacy_accepted_at: nowIso,
        pearls_rules_accepted_at: nowIso
      },
      {
        id: staff.user.id,
        display_name: 'Staff E2E',
        status: 'active',
        terms_accepted_at: nowIso,
        privacy_accepted_at: nowIso,
        pearls_rules_accepted_at: nowIso
      }
    ]
  })

  // Add staff user to staff_members
  await adminQuery('staff_members', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [{ user_id: staff.user.id, role: 'staff', active: true }]
  })

  return { fanEmail, staffEmail }
}

test.describe('Fase 8: Panel de Staff (apps/admin)', () => {
  let credentials: { fanEmail: string; staffEmail: string }

  test.beforeAll(async () => {
    credentials = await setupE2EUsers()
  })

  test.beforeEach(async ({ page, context }) => {
    await context.clearCookies()
  })

  test('Deniega acceso a fanáticos sin rol de personal', async ({ page }) => {
    await page.goto(`${ADMIN_URL}/login`)
    await page.evaluate(() => localStorage.clear())

    await page.fill('input[type="email"]', credentials.fanEmail)
    await page.fill('input[type="password"]', 'Password123!')
    await page.click('button[type="submit"]')

    // Must show alert box with error message
    await expect(page.locator('.bg-red-950\\/50')).toBeVisible({ timeout: 10000 })
    await expect(page.locator('form')).toBeVisible()
  })

  test('Permite ingreso exitoso a personal autorizado y permite navegación', async ({ page }) => {
    await page.goto(`${ADMIN_URL}/login`)
    await page.evaluate(() => localStorage.clear())

    await page.fill('input[type="email"]', credentials.staffEmail)
    await page.fill('input[type="password"]', 'Password123!')
    await page.click('button[type="submit"]')

    // Should redirect to /staff/cola
    await page.waitForURL('**/staff/cola', { timeout: 10000 })
    await expect(page.locator('h1')).toContainText('Cola de Canjes')

    // Navigate to Escáner QR
    await page.click('text=Escáner QR')
    await page.waitForURL('**/staff/escaner')
    await expect(page.locator('h1')).toContainText('Escáner de Canjes QR')

    // Verify manual code input
    await page.fill('input[placeholder*="EJ: 3JK9"]', '012345678901')
    await page.click('button:has-text("Verificar Código")')

    // Navigate to Inventario
    await page.click('text=Inventario')
    await page.waitForURL('**/staff/inventario')
    await expect(page.locator('h1')).toContainText('Inventario de Taquilla')

    // Navigate to Consulta de Fans
    await page.click('text=Consulta de Fans')
    await page.waitForURL('**/staff/fanaticos')
    await expect(page.locator('h1')).toContainText('Consulta de Fanáticos')

    // Min 3 chars search
    await page.fill('input[placeholder*="Buscar por nombre"]', 'Fan E2E')
    await page.click('button:has-text("Buscar Fanático")')

    // Verify privacy enforcement (no email or birthdate inputs in DOM)
    const emailInput = page.locator('input[type="email"]')
    await expect(emailInput).toHaveCount(0)
  })
})
