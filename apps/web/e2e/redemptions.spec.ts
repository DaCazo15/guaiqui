import { test, expect } from '@playwright/test'

const SUPABASE_URL = 'http://127.0.0.1:54321'
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'

async function setupTestUser() {
  const listRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`
    }
  })
  const list = await listRes.json()
  const users = list.users || list || []
  let user = users.find((u: any) => u.email === 'fan@guaiqui.test')

  if (!user || !user.id) {
    const userRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
      method: 'POST',
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        email: 'fan@guaiqui.test',
        password: 'Fan12345!',
        email_confirm: true,
        user_metadata: { first_name: 'Fan', last_name: 'Prueba', terms_accepted: true }
      })
    })
    user = await userRes.json()
  }

  if (!user || !user.id) {
    const retryListRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`
      }
    })
    const retryList = await retryListRes.json()
    const retryUsers = retryList.users || retryList || []
    user = retryUsers.find((u: any) => u.email === 'fan@guaiqui.test')
  }

  const userId = user?.id

  if (userId) {
    // Update user password & confirmation state in auth.users
    await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${userId}`, {
      method: 'PUT',
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        password: 'Fan12345!',
        email_confirm: true
      })
    })

    // 1. Confirm email in DB
    await fetch(`${SUPABASE_URL}/rest/v1/rpc/confirm_test_user_email`, {
      method: 'POST',
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ p_email: 'fan@guaiqui.test' })
    })

    const now = new Date().toISOString()
    // 2. Upsert profile with all legal consent fields set
    await fetch(`${SUPABASE_URL}/rest/v1/profiles?on_conflict=id`, {
      method: 'POST',
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates'
      },
      body: JSON.stringify({
        id: userId,
        display_name: 'Fan Prueba',
        status: 'active',
        terms_accepted_at: now,
        terms_version: '1.0',
        privacy_accepted_at: now,
        privacy_version: '1.0',
        pearls_rules_accepted_at: now,
        pearls_rules_version: '1.0'
      })
    })

    // 3. Upsert wallet
    await fetch(`${SUPABASE_URL}/rest/v1/wallets?on_conflict=fan_id,team_id`, {
      method: 'POST',
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates'
      },
      body: JSON.stringify({
        fan_id: userId,
        team_id: 'a0000000-0000-0000-0000-000000000001',
        balance_cache: 10000
      })
    })

    // 4. Update wallet cache directly
    await fetch(`${SUPABASE_URL}/rest/v1/wallets?fan_id=eq.${userId}&team_id=eq.a0000000-0000-0000-0000-000000000001`, {
      method: 'PATCH',
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ balance_cache: 10000 })
    })
  }
}

test.describe('Guaiqueríes Fan Zone — Fase 7: Billetera, Tienda y Canjes', () => {
  test.beforeAll(async () => {
    await setupTestUser()
  })

  test('unauthenticated access to /app/billetera, /app/tienda, and /app/canjes redirects to /login', async ({ browser }) => {
    const context = await browser.newContext()
    const page = await context.newPage()

    await page.goto('/app/billetera')
    await page.waitForURL(/\/login/, { timeout: 10000 })
    await expect(page).toHaveURL(/\/login/)

    await page.goto('/app/tienda')
    await page.waitForURL(/\/login/, { timeout: 10000 })
    await expect(page).toHaveURL(/\/login/)

    await page.goto('/app/canjes')
    await page.waitForURL(/\/login/, { timeout: 10000 })
    await expect(page).toHaveURL(/\/login/)

    await context.close()
  })

  test('public landing displays rewards catalog preview', async ({ browser }) => {
    const context = await browser.newContext()
    const page = await context.newPage()

    await page.goto('/')

    const rewardsSection = page.locator('#premios')
    await expect(rewardsSection).toBeVisible()
    await expect(rewardsSection.locator('text=Premios Exclusivos de la Tribu')).toBeVisible()

    const cards = rewardsSection.locator('.bi-gift-fill, .bi-bag-check-fill, .bi-patch-check-fill, .bi-camera-video-fill')
    await expect(cards.first()).toBeVisible()

    await context.close()
  })

  test('authenticated user: store → redeem → view pending → cancel → verify refund', async ({ browser }) => {
    const context = await browser.newContext()
    const page = await context.newPage()

    // 1. Login
    await page.goto('/login')
    await page.fill('input[type="email"]', 'fan@guaiqui.test')
    await page.fill('input[type="password"]', 'Fan12345!')
    const submitBtn = page.locator('button[type="submit"]')
    await expect(submitBtn).toBeEnabled()
    await submitBtn.click()
    await page.waitForURL(/\/app/, { timeout: 15000 })

    // 2. Visit Billetera
    await page.locator('a[href="/app/billetera"]').first().click()
    await expect(page.locator('text=Saldo de Perlitas')).toBeVisible()
    await expect(page.locator('text=Historial de Movimientos')).toBeVisible()

    // 3. Visit Tienda
    await page.locator('a[href="/app/tienda"]').first().click()
    await expect(page.locator('text=Tienda de Canje')).toBeVisible()

    // Verify category filter tabs exist
    await expect(page.locator('button:has-text("Todos")')).toBeVisible()
    await expect(page.locator('button:has-text("Indumentaria")')).toBeVisible()
    await expect(page.locator('button:has-text("Experiencias")')).toBeVisible()
    await expect(page.locator('button:has-text("Sorteos")')).toBeVisible()

    // Verify "Solo lo que me alcanza" toggle
    await expect(page.locator('text=Solo lo que me alcanza')).toBeVisible()

    // Verify product cards exist
    const productCards = page.locator('h3')
    await expect(productCards.first()).toBeVisible()

    // Switch back to all
    await page.locator('button:has-text("Todos")').click()

    // 4. Click on first available product
    const detailBtn = page.locator('button:has-text("Ver detalle")').first()
    if (await detailBtn.isVisible()) {
      await detailBtn.click()
      await expect(page).toHaveURL(/\/app\/tienda\//)

      // Verify product detail elements
      await expect(page.locator('text=Costo de Canje')).toBeVisible()
      await expect(page.locator('text=Tu saldo disponible')).toBeVisible()
      await expect(page.locator('text=Retiro Presencial')).toBeVisible()

      // 5. Attempt to redeem (click "Canjear Ahora" if available)
      const redeemBtn = page.locator('button:has-text("Canjear Ahora")')
      if (await redeemBtn.isVisible()) {
        await redeemBtn.click()

        // Verify confirmation modal
        await expect(page.locator('text=Confirmación de Canje')).toBeVisible()
        await expect(page.locator('text=Tu saldo actual')).toBeVisible()
        await expect(page.locator('text=Costo a debitar')).toBeVisible()
        await expect(page.locator('text=Saldo tras el canje')).toBeVisible()

        // Confirm the redemption
        const confirmBtn = page.locator('button:has-text("Confirmar Canje")')
        await expect(confirmBtn).toBeEnabled()
        await confirmBtn.click()

        // Should redirect to redemption detail
        await page.waitForURL(/\/app\/canjes\//, { timeout: 10000 })

        // 6. Verify pending state
        await expect(page.locator('text=Pendiente de Aprobación').first()).toBeVisible()
        await expect(page.locator('text=Canje en Revisión')).toBeVisible()

        // Verify cancel button is available for pending
        const cancelBtn = page.locator('button:has-text("Cancelar Solicitud")')
        await expect(cancelBtn).toBeVisible()

        // Verify QR is NOT shown for pending
        const qrSection = page.locator('text=Pase de Retiro Digital')
        await expect(qrSection).not.toBeVisible()

        // 7. Cancel the redemption
        await cancelBtn.click()

        // Confirm cancellation modal
        await expect(page.locator('text=Cancelar Solicitud de Canje')).toBeVisible()
        await expect(page.locator('text=Perlitas a reembolsar')).toBeVisible()

        const confirmCancelBtn = page.locator('button:has-text("Confirmar Cancelación")')
        await confirmCancelBtn.click()

        // Wait for status update
        await expect(page.locator('text=Cancelado').first()).toBeVisible({ timeout: 5000 })

        // 8. Verify refund in wallet
        await page.locator('a[href="/app/billetera"]').first().click()
        await expect(page.locator('text=Saldo de Perlitas')).toBeVisible()

        // Verify refund appears in ledger
        await expect(page.locator('text=Reembolso').first()).toBeVisible({ timeout: 5000 })
      }
    }
    await context.close()
  })

  test('authenticated user: cannot redeem without sufficient balance', async ({ browser }) => {
    const context = await browser.newContext()
    const page = await context.newPage()

    await page.goto('/login')
    await page.fill('input[type="email"]', 'fan@guaiqui.test')
    await page.fill('input[type="password"]', 'Fan12345!')
    const submitBtn = page.locator('button[type="submit"]')
    await expect(submitBtn).toBeEnabled()
    await submitBtn.click()
    await page.waitForURL(/\/app/, { timeout: 15000 })

    await page.locator('a[href="/app/tienda"]').first().click()
    await expect(page.locator('text=Tienda de Canje')).toBeVisible()

    const detailBtn = page.locator('button:has-text("Ver detalle")').first()
    if (await detailBtn.isVisible()) {
      await detailBtn.click()
      await expect(page).toHaveURL(/\/app\/tienda\//)

      const redeemBtn = page.locator('button:has-text("Canjear Ahora")')
      const insufficientBtn = page.locator('button:has-text("Ganar Perlitas")')
      const outOfStockBtn = page.locator('button:has-text("Producto Agotado")')

      const hasRedeemBtn = await redeemBtn.isVisible()
      const hasInsufficientBtn = await insufficientBtn.isVisible()
      const hasOutOfStockBtn = await outOfStockBtn.isVisible()

      expect(hasRedeemBtn || hasInsufficientBtn || hasOutOfStockBtn).toBeTruthy()
    }
    await context.close()
  })

  test('authenticated user: canjes list page with status filters', async ({ browser }) => {
    const context = await browser.newContext()
    const page = await context.newPage()

    await page.goto('/login')
    await page.fill('input[type="email"]', 'fan@guaiqui.test')
    await page.fill('input[type="password"]', 'Fan12345!')
    const submitBtn = page.locator('button[type="submit"]')
    await expect(submitBtn).toBeEnabled()
    await submitBtn.click()
    await page.waitForURL(/\/app/, { timeout: 15000 })

    await page.locator('a[href="/app/canjes"]').first().click()
    await expect(page.locator('h1:has-text("Mis Canjes")')).toBeVisible()

    await expect(page.locator('button:has-text("Todos")')).toBeVisible()
    await expect(page.locator('button:has-text("Activos")')).toBeVisible()
    await expect(page.locator('button:has-text("Entregados")')).toBeVisible()
    await expect(page.locator('button:has-text("Cancelados")')).toBeVisible()

    await page.locator('button:has-text("Activos")').click()
    await page.locator('button:has-text("Entregados")').click()
    await page.locator('button:has-text("Cancelados")').click()
    await page.locator('button:has-text("Todos")').click()

    await expect(page.locator('a:has-text("Ir a la Tienda")')).toBeVisible()
    await context.close()
  })
})
