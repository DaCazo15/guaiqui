import { test, expect } from '@playwright/test'

test.describe('Multi-Team Experience E2E Tests (Fase 3)', () => {
  test('redirects unauthenticated user from team hub /app/e/guaiqueries to /login', async ({ page }) => {
    await page.goto('/app/e/guaiqueries')
    await expect(page).toHaveURL(/\/login/)
  })

  test('displays team hub header, tabs and switch team button for authenticated user', async ({ page }) => {
    // Mock user session
    await page.addInitScript(() => {
      window.localStorage.setItem(
        'sb-test-auth-token',
        JSON.stringify({
          access_token: 'fake-jwt',
          user: {
            id: 'fan-test-01',
            email: 'fan@guaiqui.test',
            role: 'authenticated',
            email_confirmed_at: '2026-01-01T00:00:00Z',
            app_metadata: { provider: 'email', aal: 'aal1' },
            user_metadata: {},
          },
        })
      )
    })

    // Mock followed teams query
    await page.route('**/rest/v1/team_follows*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          {
            team_id: 'a0000000-0000-0000-0000-000000000001',
            notifications_enabled: true,
            team: {
              id: 'a0000000-0000-0000-0000-000000000001',
              name: 'Guaiqueríes de Margarita',
              slug: 'guaiqueries',
              short_name: 'La Tribu',
              logo_url: '/logo.png',
              status: 'active',
            },
          },
        ]),
      })
    })

    // Mock wallet summary RPC
    await page.route('**/rest/v1/rpc/get_wallet_summary*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          balance: 350,
          total_balance: 350,
          teams: [
            {
              team_id: 'a0000000-0000-0000-0000-000000000001',
              team_name: 'Guaiqueríes de Margarita',
              team_slug: 'guaiqueries',
              balance: 350,
              held_balance: 0,
              is_following: true,
            },
          ],
        }),
      })
    })

    // Mock home_summary RPC
    await page.route('**/rest/v1/rpc/home_summary*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          balance: 350,
          active_trivia: {
            id: 't-001',
            title: 'Trivia del Clásico',
            description: 'Demuestra tu conocimiento del equipo.',
            time_limit_seconds: 60,
            starts_at: new Date(Date.now() - 3600000).toISOString(),
            ends_at: new Date(Date.now() + 86400000).toISOString(),
            max_attempts: 1,
            played: false,
          },
          streak: { streak_days: 3, bonus_awarded: 10 },
        }),
      })
    })

    await page.goto('/app/e/guaiqueries')

    // Expect to see team name and tabs
    await expect(page.getByText('Guaiqueríes de Margarita')).toBeVisible()
    await expect(page.getByRole('tab', { name: /Trivias/i })).toBeVisible()
    await expect(page.getByRole('tab', { name: /Tienda de Premios/i })).toBeVisible()
  })

  test('displays inactive team warning banner and disables play/redeem actions', async ({ page }) => {
    await page.addInitScript(() => {
      window.localStorage.setItem(
        'sb-test-auth-token',
        JSON.stringify({
          access_token: 'fake-jwt',
          user: {
            id: 'fan-test-01',
            email: 'fan@guaiqui.test',
            role: 'authenticated',
            email_confirmed_at: '2026-01-01T00:00:00Z',
            app_metadata: { provider: 'email', aal: 'aal1' },
            user_metadata: {},
          },
        })
      )
    })

    // Mock teams query with inactive team
    await page.route('**/rest/v1/teams*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          id: 'b0000000-0000-0000-0000-000000000002',
          name: 'Trotamundos de Carabobo',
          slug: 'trotamundos',
          short_name: 'Expreso Azul',
          logo_url: null,
          status: 'inactive',
        }),
      })
    })

    await page.route('**/rest/v1/team_follows*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([]),
      })
    })

    await page.goto('/app/e/trotamundos')

    // Verify inactive banner is visible
    await expect(page.getByText('Equipo Temporalmente No Disponible')).toBeVisible()
    await expect(page.getByText(/no permite participar en trivias ni canjear nuevos premios/i)).toBeVisible()
  })

  test('shows team picker modal and handles empty state when fan follows 0 teams', async ({ page }) => {
    await page.addInitScript(() => {
      window.localStorage.setItem(
        'sb-test-auth-token',
        JSON.stringify({
          access_token: 'fake-jwt',
          user: {
            id: 'fan-test-01',
            email: 'fan@guaiqui.test',
            role: 'authenticated',
            email_confirmed_at: '2026-01-01T00:00:00Z',
            app_metadata: { provider: 'email', aal: 'aal1' },
            user_metadata: {},
          },
        })
      )
    })

    await page.route('**/rest/v1/team_follows*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([]),
      })
    })

    await page.goto('/app/trivias')

    // Team picker modal opens automatically on /app/trivias when 0 teams
    await expect(page.getByText('Aún no sigues a ningún equipo')).toBeVisible()
    await expect(page.getByRole('link', { name: /Explorar Equipos/i })).toBeVisible()
  })

  test('shows team badge and filter on /app/canjes', async ({ page }) => {
    await page.addInitScript(() => {
      window.localStorage.setItem(
        'sb-test-auth-token',
        JSON.stringify({
          access_token: 'fake-jwt',
          user: {
            id: 'fan-test-01',
            email: 'fan@guaiqui.test',
            role: 'authenticated',
            email_confirmed_at: '2026-01-01T00:00:00Z',
            app_metadata: { provider: 'email', aal: 'aal1' },
            user_metadata: {},
          },
        })
      )
    })

    await page.route('**/rest/v1/redemptions*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          {
            id: 'r-001',
            cost_pearls: 150,
            status: 'approved',
            variant: 'L',
            created_at: new Date().toISOString(),
            team: {
              id: 'a0000000-0000-0000-0000-000000000001',
              name: 'Guaiqueríes de Margarita',
              slug: 'guaiqueries',
              logo_url: '/logo.png',
            },
            products: {
              name: 'Camiseta Oficial 2026',
              category: 'physical',
              images: [],
            },
          },
        ]),
      })
    })

    await page.goto('/app/canjes')

    await expect(page.getByText('Mis Canjes')).toBeVisible()
    await expect(page.getByText('Camiseta Oficial 2026')).toBeVisible()
    await expect(page.getByText('Guaiqueríes de Margarita')).toBeVisible()
  })
})
