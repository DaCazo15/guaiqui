import { test, expect } from '@playwright/test'

test.describe('Fase 7 — Perfil Enriquecido, Billetera y Ranking Multi-Equipo @profile-ranking', () => {
  test('La vista de ranking carga filtro multi-equipo y tabs de período', async ({ page }) => {
    await page.goto('/app/ranking')
    await expect(page.locator('h1')).toContainText(/Tabla de Posiciones/i)

    // Selector de equipos presente
    await expect(page.getByRole('button', { name: /Todos los Equipos/i })).toBeVisible()

    // Tabs de período
    await expect(page.getByRole('button', { name: /Ranking General/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /Ranking Mensual/i })).toBeVisible()
    await expect(page.getByRole('button', { name: /Ranking Semanal/i })).toBeVisible()
  })

  test('La vista de billetera incluye sección de quién te refirió y mis referidos', async ({ page }) => {
    await page.goto('/app/billetera')
    await expect(page.locator('h1')).toContainText(/Billetera de Puntos/i)

    // Sección ¿Quién te refirió?
    await expect(page.getByText(/¿Quién te refirió\?/i)).toBeVisible()

    // Sección Mis Referidos
    await expect(page.getByText(/Mis Referidos/i)).toBeVisible()
    await expect(page.getByText(/Puntos Obtenidos/i)).toBeVisible()
  })

  test('La vista de perfil carga el nivel de fanático e insignias', async ({ page }) => {
    await page.goto('/app/perfil')
    await expect(page.getByText(/Nivel de Fanático/i)).toBeVisible()
    await expect(page.getByText(/Insignias y Logros/i)).toBeVisible()
    await expect(page.getByText(/Equipos que Sigues/i)).toBeVisible()
  })
})
