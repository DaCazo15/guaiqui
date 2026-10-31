import { test, expect } from '@playwright/test'

test.describe('Fase 8 — Red Social, Amigos y Ranking entre Amigos @friendships-social', () => {
  test('La vista de amigos carga pestañas de navegación y lista', async ({ page }) => {
    await page.goto('/app/amigos')
    await expect(page.locator('h1')).toContainText(/Comunidad de Amigos/i)

    // Tabs de navegación
    await expect(page.getByRole('button', { name: /Amigos/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /Solicitudes/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /Agregar Fanático/i })).toBeVisible()
  })

  test('La pestaña de agregar fanático muestra formulario y código propio', async ({ page }) => {
    await page.goto('/app/amigos')
    await page.getByRole('button', { name: /Agregar Fanático/i }).click()

    await expect(page.getByText(/Tu Código Personal de Fanático/i)).toBeVisible()
    await expect(page.getByPlaceholder(/Código de 8 caracteres/i)).toBeVisible()
    await expect(page.getByRole('button', { name: /Enviar Solicitud/i })).toBeVisible()
  })

  test('El ranking incluye el filtro para ver exclusivamente a los amigos', async ({ page }) => {
    await page.goto('/app/ranking')
    await expect(page.locator('h1')).toContainText(/Tabla de Posiciones/i)

    const friendsFilterBtn = page.getByRole('button', { name: /Filtrar por Amigos|Solo Amigos/i })
    await expect(friendsFilterBtn).toBeVisible()
    await friendsFilterBtn.click()

    await expect(page.getByRole('button', { name: /Solo Amigos \(Activo\)/i })).toBeVisible()
  })
})
