import { test, expect } from '@playwright/test'

test('la app web carga correctamente', async ({ page }) => {
  await page.goto('/')
  await expect(page).toHaveTitle(/Guaiquer/i)
})
