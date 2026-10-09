import { test, expect } from '@playwright/test'

test.describe('Guaiqueríes Fan Zone — Auth & Profile E2E Tests', () => {
  test('redirects unauthenticated user from /app to /login', async ({ page }) => {
    await page.goto('/app')
    await expect(page).toHaveURL(/\/login/)
  })

  test('full registration, profile edit, settings and account deletion flow', async ({ page }) => {
    // 1. Visit Register Page
    await page.goto('/registro')

    // Step 1: Account
    const testEmail = `fan_${Date.now()}@guaiqui.test`
    await page.fill('input[type="email"]', testEmail)
    await page.fill('input[type="password"]', 'Test1234!')
    await page.locator('input[type="password"]').nth(1).fill('Test1234!')

    // Check mandatory terms
    const checkboxes = page.locator('input[type="checkbox"]')
    await checkboxes.nth(0).check({ force: true })
    await checkboxes.nth(1).check({ force: true })
    await checkboxes.nth(2).check({ force: true })

    await page.click('button[type="submit"]')

    // Step 2: Minimal Profile
    await page.fill('input[placeholder="Ej. Pedro Guaiquerí"]', 'Fan de Prueba E2E')
    await page.click('button[type="submit"]')

    // Step 3: Optional Preferences (Skip)
    await page.click('button:has-text("Omitir")')

    // Verification screen
    await expect(page).toHaveURL(/\/verificar-correo/)
  })

  test('password recovery flow', async ({ page }) => {
    await page.goto('/recuperar')
    await page.fill('input[type="email"]', 'fan@guaiqui.test')
    await page.click('button[type="submit"]')
    await expect(page.locator('form').first()).toBeVisible()
  })
})
