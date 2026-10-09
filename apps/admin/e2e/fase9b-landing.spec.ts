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
  const adminEmail = `admin_e2e_f9b_${time}@guaiqui.test`

  const adminUser = await signUpOrSignInUser(adminEmail)
  const nowIso = new Date().toISOString()

  await adminQuery('profiles', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [
      { id: adminUser.user.id, display_name: 'Admin E2E F9B', status: 'active', terms_accepted_at: nowIso, privacy_accepted_at: nowIso, pearls_rules_accepted_at: nowIso }
    ]
  })

  await adminQuery('staff_members', {
    method: 'POST',
    headers: { 'Prefer': 'resolution=merge-duplicates' },
    body: [
      { user_id: adminUser.user.id, role: 'admin', active: true }
    ]
  })

  return { adminEmail }
}

test.describe('Fase 9B: Gestión de Contenidos Landing & Políticas (apps/admin)', () => {
  let credentials: { adminEmail: string }

  test.beforeAll(async () => {
    credentials = await setupAdminE2EUsers()
  })

  test.beforeEach(async ({ page, context }) => {
    await context.clearCookies()
  })

  test('Administrador puede crear un anuncio en la cinta superior', async ({ page }) => {
    await page.goto(`${ADMIN_URL}/login`)
    await page.evaluate(() => localStorage.clear())

    await page.fill('input[type="email"]', credentials.adminEmail)
    await page.fill('input[type="password"]', 'Password123!')
    await page.click('button[type="submit"]')

    await page.waitForURL('**/admin/dashboard')
    await page.click('text=Cinta Anuncios')
    await page.waitForURL('**/admin/anuncios')

    await page.click('button:has-text("Nuevo Anuncio")')
    await page.fill('input[placeholder*="Ej: ¡Hoy jugamos en casa!"]', '¡Atención Fanáticos: Trivia Activa!')
    await page.click('button:has-text("Guardar Anuncio")')

    await expect(page.locator('td:has-text("¡Atención Fanáticos: Trivia Activa!")')).toBeVisible({ timeout: 10000 })
  })

  test('Administrador puede crear una diapositiva en el carrusel', async ({ page }) => {
    await page.goto(`${ADMIN_URL}/login`)
    await page.evaluate(() => localStorage.clear())

    await page.fill('input[type="email"]', credentials.adminEmail)
    await page.fill('input[type="password"]', 'Password123!')
    await page.click('button[type="submit"]')

    await page.waitForURL('**/admin/dashboard')
    await page.click('text=Carrusel Hero')
    await page.waitForURL('**/admin/carrusel')

    await page.click('button:has-text("Nueva Diapositiva")')
    await page.fill('input[placeholder*="Ej: Gran Clásico"]', 'Gran Final SPB 2026')
    await page.fill('input[placeholder*="Ej: Responde la trivia"]', 'Apoya a la tribu en el gimnasio')
    await page.click('button:has-text("Guardar Diapositiva")')

    await expect(page.locator('td:has-text("Gran Final SPB 2026")')).toBeVisible({ timeout: 10000 })
  })

  test('Administrador puede publicar una nueva versión de términos y condiciones', async ({ page }) => {
    await page.goto(`${ADMIN_URL}/login`)
    await page.evaluate(() => localStorage.clear())

    await page.fill('input[type="email"]', credentials.adminEmail)
    await page.fill('input[type="password"]', 'Password123!')
    await page.click('button[type="submit"]')

    await page.waitForURL('**/admin/dashboard')
    await page.click('text=Políticas Legales')
    await page.waitForURL('**/admin/politicas')

    await page.click('button:has-text("Publicar Nueva Versión"):first-child')
    await page.fill('input[placeholder="v1.1"]', 'v2.0')
    await page.fill('textarea[placeholder*="# Titulo"]', '# Términos Actualizados v2.0\n\nNuevas reglas para el canje de perlitas.')
    await page.click('button:has-text("Publicar Versión")')

    await expect(page.locator('span:has-text("v2.0")')).toBeVisible({ timeout: 10000 })
  })
})
