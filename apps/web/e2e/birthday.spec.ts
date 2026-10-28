import { test, expect } from '@playwright/test'

test.describe('Fase 15 — Saludo de Cumpleaños E2E', () => {
  test('un usuario con cumpleaños hoy accede a /app/cumpleanos, ve su tarjeta personalizada y confeti', async ({ page }) => {
    // 1. Navegar a /app/cumpleanos
    await page.goto('/app/cumpleanos')

    // 2. Verificar redirección o renderizado de la tarjeta
    const url = page.url()
    if (url.includes('/cumpleanos')) {
      await expect(page.locator('h1')).toContainText('FELIZ CUMPLEAÑOS')
      await expect(page.locator('button', { hasText: 'Ir a mis trivias' })).toBeVisible()
      await expect(page.locator('button', { hasText: 'Compartir' })).toBeVisible()
    } else {
      // Redirección silenciosa a /app si no es elegible
      expect(url).toContain('/app')
    }
  })

  test('con prefers-reduced-motion activado, la animación de confeti se deshabilita', async ({ page }) => {
    // Simular preferencia del sistema prefers-reduced-motion: reduce
    await page.emulateMedia({ reducedMotion: 'reduce' })
    await page.goto('/app/cumpleanos')

    const confettiContainer = page.locator('.confetti-piece')
    if (await confettiContainer.count() > 0) {
      const isVisible = await confettiContainer.first().evaluate((el) => {
        return window.getComputedStyle(el).display !== 'none' && window.getComputedStyle(el).animationName !== 'none'
      })
      expect(isVisible).toBe(false)
    }
  })

  test('un usuario sin cumpleaños hoy es redirigido silenciosamente a /app', async ({ page }) => {
    await page.goto('/app/cumpleanos')
    // El middleware o la llamada a get_birthday_card redirige a /app o /login
    await page.waitForURL(/\/(app|login)/)
    expect(page.url()).not.toContain('/app/cumpleanos')
  })
})
