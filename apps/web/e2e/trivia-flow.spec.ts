import { test, expect } from '@playwright/test'

test.describe('Guaiqueríes Fan Zone — Trivia & Leaderboard E2E Tests', () => {
  test('redirects unauthenticated user from /app/trivias to /login', async ({ page }) => {
    await page.goto('/app/trivias')
    await expect(page).toHaveURL(/\/login/)
  })

  test('unauthenticated or unverified access to trivias and ranking is protected', async ({ page }) => {
    await page.goto('/app/trivias')
    await expect(page).toHaveURL(/\/(login|verificar-correo)/)

    await page.goto('/app/ranking')
    await expect(page).toHaveURL(/\/(login|verificar-correo)/)
  })
})
