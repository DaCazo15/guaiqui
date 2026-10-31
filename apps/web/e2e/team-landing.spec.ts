import { test, expect } from '@playwright/test'

test.describe('Fase 6 — Landing Pública por Equipo y Subdominios @team-landing', () => {
  test('Carga la landing oficial por ruta directa /equipo/guaiqueries', async ({ page }) => {
    await page.goto('/equipo/guaiqueries')
    await expect(page).toHaveTitle(/Guaiqueríes de Margarita/i)

    // Hero visible con nombre y escudo
    const heroTitle = page.locator('#hero h1')
    await expect(heroTitle).toBeVisible()
    await expect(heroTitle).toContainText(/Guaiqueríes/i)

    // Secciones principales montadas
    await expect(page.locator('#plantilla')).toBeVisible()
    await expect(page.locator('#trivias')).toBeVisible()
    await expect(page.locator('#tienda')).toBeVisible()
    await expect(page.locator('#historia')).toBeVisible()
    await expect(page.locator('#faq')).toBeVisible()
  })

  test('Redirige automáticamente de /equipos/:slug a /equipo/:slug', async ({ page }) => {
    await page.goto('/equipos/guaiqueries')
    await expect(page).toHaveURL(/\/equipo\/guaiqueries/)
  })

  test('Muestra estado amigable para equipo inexistente', async ({ page }) => {
    await page.goto('/equipo/equipo-fantasma-xyz')
    await expect(page.getByText(/Equipo no disponible/i)).toBeVisible()
  })

  test('Preserva el contexto del equipo al hacer clic en Unirme', async ({ page }) => {
    await page.goto('/equipo/guaiqueries')
    const joinButton = page.getByRole('link', { name: /Unirme a/i }).first()
    await expect(joinButton).toHaveAttribute('href', /registro\?team=guaiqueries/)
  })
})
