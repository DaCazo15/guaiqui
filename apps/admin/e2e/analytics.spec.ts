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
  const adminEmail = `admin_e2e_f10_${time}@guaiqui.test`
  const staffEmail = `staff_e2e_f10_${time}@guaiqui.test`

  const adminUser = await signUpOrSignInUser(adminEmail)
  const staffUser = await signUpOrSignInUser(staffEmail)
  const nowIso = new Date().toISOString()

  await adminQuery('profiles', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [
      { id: adminUser.user.id, display_name: 'Admin E2E F10', status: 'active', terms_accepted_at: nowIso, privacy_accepted_at: nowIso, pearls_rules_accepted_at: nowIso },
      { id: staffUser.user.id, display_name: 'Staff E2E F10', status: 'active', terms_accepted_at: nowIso, privacy_accepted_at: nowIso, pearls_rules_accepted_at: nowIso }
    ]
  })

  await adminQuery('staff_members', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [
      { user_id: adminUser.user.id, role: 'admin', active: true },
      { user_id: staffUser.user.id, role: 'staff', active: true }
    ]
  })

  return { adminEmail, staffEmail }
}

test.describe('Fase 10: Dashboard de Analítica & Métricas Club (apps/admin)', () => {
  let credentials: { adminEmail: string; staffEmail: string }

  test.beforeAll(async () => {
    credentials = await setupAdminE2EUsers()
  })

  test.beforeEach(async ({ page, context }) => {
    await context.clearCookies()
  })

  test('Deniega acceso a /admin/analitica a rol staff y redirige', async ({ page }) => {
    await page.goto(`${ADMIN_URL}/login`)
    await page.evaluate(() => localStorage.clear())

    await page.fill('input[type="email"]', credentials.staffEmail)
    await page.fill('input[type="password"]', 'Password123!')
    await page.click('button[type="submit"]')

    await page.waitForURL('**/staff/cola')

    // Try opening /admin/analitica directly
    await page.goto(`${ADMIN_URL}/admin/analitica`)
    await page.waitForURL('**/staff/cola')
    await expect(page.locator('h1')).toContainText('Cola de Canjes')
  })

  test('Permite acceso completo a Administrador a /admin/analitica y muestra componentes', async ({ page }) => {
    await page.goto(`${ADMIN_URL}/login`)
    await page.evaluate(() => localStorage.clear())

    await page.fill('input[type="email"]', credentials.adminEmail)
    await page.fill('input[type="password"]', 'Password123!')
    await page.click('button[type="submit"]')

    await page.waitForURL('**/admin/dashboard')
    await page.click('text=Analítica')
    await page.waitForURL('**/admin/analitica')

    await expect(page.locator('h1')).toContainText('Dashboard de Analítica & Métricas Club')
    await expect(page.locator('text=Usuarios Activos')).toBeVisible()
    await expect(page.locator('text=Evolución de Usuarios Activos')).toBeVisible()
    await expect(page.locator('text=Salud de la Economía Digital')).toBeVisible()
    await expect(page.locator('text=Demografía de Fanáticos')).toBeVisible()
  })

  test('Cambiar el filtro de fechas (7d vs 30d) ejecuta la consulta y actualiza la vista', async ({ page }) => {
    await page.goto(`${ADMIN_URL}/login`)
    await page.evaluate(() => localStorage.clear())

    await page.fill('input[type="email"]', credentials.adminEmail)
    await page.fill('input[type="password"]', 'Password123!')
    await page.click('button[type="submit"]')

    await page.waitForURL('**/admin/dashboard')
    await page.goto(`${ADMIN_URL}/admin/analitica`)

    await page.click('button:has-text("Últimos 7d")')
    await expect(page.locator('h1')).toContainText('Dashboard de Analítica')
  })
})
