import { test, expect } from '@playwright/test'

// E2E Tests for Platform Team Management (Dominio: platform-teams)
// Cubre: Alta de equipo -> Registrar pago -> Desactivación -> Aislamiento de permisos y equipo inactivo

test.describe('Platform Admin: Team Management & Governance', () => {
  const platformAdminSession = {
    access_token: 'fake-platform-admin-jwt',
    user: {
      id: 'platform-admin-user-01',
      email: 'master@guaiqui.test',
      role: 'authenticated',
      email_confirmed_at: '2026-01-01T00:00:00Z',
      app_metadata: { provider: 'email', aal: 'aal2' },
      user_metadata: { first_name: 'Master', last_name: 'Admin' },
    },
  }

  const clubAdminSession = {
    access_token: 'fake-club-admin-jwt',
    user: {
      id: 'club-admin-user-01',
      email: 'staff.guaiqueries@guaiqui.test',
      role: 'authenticated',
      email_confirmed_at: '2026-01-01T00:00:00Z',
      app_metadata: { provider: 'email', aal: 'aal1' },
      user_metadata: { first_name: 'Club', last_name: 'Staff' },
    },
  }

  const mockTeams = [
    {
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Guaiqueríes de Margarita',
      slug: 'guaiqueries',
      short_name: 'La Tribu',
      sport: 'baloncesto',
      logo_url: '/logo.png',
      status: 'active',
      joined_at: '2026-01-01T00:00:00Z',
      paid_until: '2026-12-31T23:59:59Z',
      follower_count: 1420,
      active_staff_count: 3,
      billing_status: 'al_dia',
    },
    {
      id: 'b0000000-0000-0000-0000-000000000002',
      name: 'Cocodrilos de Caracas',
      slug: 'cocodrilos',
      short_name: 'Saurios',
      sport: 'baloncesto',
      logo_url: null,
      status: 'inactive',
      joined_at: '2026-02-01T00:00:00Z',
      paid_until: '2026-03-01T00:00:00Z',
      follower_count: 850,
      active_staff_count: 1,
      billing_status: 'vencido',
    },
  ]

  test.beforeEach(async ({ page }) => {
    // Intercept RPC and REST calls to provide isolated responses
    await page.route('**/rest/v1/rpc/admin_list_teams*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockTeams),
      })
    })

    await page.route('**/rest/v1/teams*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockTeams),
      })
    })

    await page.route('**/rest/v1/team_billing_events*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          {
            id: 'evt-1',
            team_id: 'a0000000-0000-0000-0000-000000000001',
            event_type: 'subscription_payment',
            amount: 500,
            currency: 'USD',
            period_months: 6,
            notes: 'Renovación semestral',
            recorded_at: '2026-06-01T12:00:00Z',
          },
        ]),
      })
    })
  })

  test('allows platform admin (team_id IS NULL) to view platform team directory and KPIs', async ({ page }) => {
    // Mock platform admin auth profile & staff
    await page.addInitScript((session) => {
      window.localStorage.setItem('sb-test-auth-token', JSON.stringify(session))
    }, platformAdminSession)

    await page.route('**/rest/v1/staff_members*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          {
            id: 'staff-master-01',
            user_id: 'platform-admin-user-01',
            role: 'admin',
            active: true,
            team_id: null, // Platform Master
          },
        ]),
      })
    })

    await page.goto('/admin/plataforma/equipos')
    await expect(page).toHaveURL(/\/admin\/plataforma\/equipos/)

    // Check header and KPI metrics
    await expect(page.locator('text=Directorio y Membresías de Clubes')).toBeVisible()
    await expect(page.locator('text=Total Equipos')).toBeVisible()
    await expect(page.locator('text=Guaiqueríes de Margarita')).toBeVisible()
    await expect(page.locator('text=Cocodrilos de Caracas')).toBeVisible()
  })

  test('club admin (team_id NOT NULL) is blocked from /admin/plataforma/equipos and redirected to dashboard', async ({ page }) => {
    await page.addInitScript((session) => {
      window.localStorage.setItem('sb-test-auth-token', JSON.stringify(session))
    }, clubAdminSession)

    await page.route('**/rest/v1/staff_members*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          {
            id: 'staff-club-01',
            user_id: 'club-admin-user-01',
            role: 'admin',
            active: true,
            team_id: 'a0000000-0000-0000-0000-000000000001', // Assigned to Guaiqueríes
          },
        ]),
      })
    })

    await page.goto('/admin/plataforma/equipos')
    // Should be redirected away because isPlatformAdmin is false
    await expect(page).toHaveURL(/\/admin\/dashboard/)
  })

  test('flow: alta de nuevo equipo via Edge Function create-team', async ({ page }) => {
    await page.addInitScript((session) => {
      window.localStorage.setItem('sb-test-auth-token', JSON.stringify(session))
    }, platformAdminSession)

    await page.route('**/rest/v1/staff_members*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          {
            id: 'staff-master-01',
            user_id: 'platform-admin-user-01',
            role: 'admin',
            active: true,
            team_id: null,
          },
        ]),
      })
    })

    // Mock Edge Function create-team
    let edgeFunctionCalled = false
    await page.route('**/functions/v1/create-team', async (route) => {
      edgeFunctionCalled = true
      const postData = JSON.parse(route.request().postData() || '{}')
      expect(postData.slug).toBe('gladiadores')
      expect(postData.admin_email).toBe('admin@gladiadores.test')

      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          success: true,
          team: {
            id: 'c0000000-0000-0000-0000-000000000003',
            name: postData.name,
            slug: postData.slug,
          },
        }),
      })
    })

    await page.goto('/admin/plataforma/equipos')
    await page.click('button:has-text("Nuevo Equipo")')

    // Fill team modal form
    await page.fill('#team-name', 'Gladiadores de Anzoátegui')
    await page.fill('#team-slug', 'gladiadores')
    await page.fill('#admin-email', 'admin@gladiadores.test')
    await page.fill('#admin-first-name', 'Carlos')
    await page.fill('#admin-last-name', 'Silva')

    await page.click('button:has-text("Crear Equipo y Enviar Invitación")')
    await expect(page.locator('text=Equipo creado y admin invitado exitosamente.')).toBeVisible()
    expect(edgeFunctionCalled).toBe(true)
  })

  test('flow: registrar pago para extender membresía de un equipo', async ({ page }) => {
    await page.addInitScript((session) => {
      window.localStorage.setItem('sb-test-auth-token', JSON.stringify(session))
    }, platformAdminSession)

    await page.route('**/rest/v1/staff_members*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          {
            id: 'staff-master-01',
            user_id: 'platform-admin-user-01',
            role: 'admin',
            active: true,
            team_id: null,
          },
        ]),
      })
    })

    let paymentRpcCalled = false
    await page.route('**/rest/v1/rpc/admin_record_team_payment', async (route) => {
      paymentRpcCalled = true
      const postData = JSON.parse(route.request().postData() || '{}')
      expect(postData.p_period_months).toBe(12)
      expect(postData.p_amount).toBe(1200)

      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          success: true,
          event_id: 'evt-new-01',
          new_paid_until: '2027-12-31T23:59:59Z',
        }),
      })
    })

    await page.goto('/admin/plataforma/equipos')
    // Click action button for Guaiqueríes: Registrar Pago
    await page.click('button[title="Registrar Pago"]:first-child, tr:has-text("Guaiqueríes") button[title="Registrar Pago"]')

    await page.selectOption('#payment-months', '12')
    await page.fill('#payment-amount', '1200')
    await page.fill('#payment-notes', 'Pago anual temporada 2027')

    await page.click('button:has-text("Confirmar y Extender Membresía")')
    await expect(page.locator('text=Pago registrado exitosamente.')).toBeVisible()
    expect(paymentRpcCalled).toBe(true)
  })

  test('flow: desactivación manual con motivo de auditoría y vista de equipo inactivo', async ({ page }) => {
    await page.addInitScript((session) => {
      window.localStorage.setItem('sb-test-auth-token', JSON.stringify(session))
    }, platformAdminSession)

    await page.route('**/rest/v1/staff_members*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          {
            id: 'staff-master-01',
            user_id: 'platform-admin-user-01',
            role: 'admin',
            active: true,
            team_id: null,
          },
        ]),
      })
    })

    let toggleRpcCalled = false
    await page.route('**/rest/v1/rpc/admin_toggle_team_status', async (route) => {
      toggleRpcCalled = true
      const postData = JSON.parse(route.request().postData() || '{}')
      expect(postData.p_new_status).toBe('inactive')
      expect(postData.p_reason).toContain('Incumplimiento de términos')

      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          success: true,
          team_id: postData.p_team_id,
          status: 'inactive',
        }),
      })
    })

    await page.goto('/admin/plataforma/equipos')
    // Click toggle status for Guaiqueríes
    await page.click('tr:has-text("Guaiqueríes") button[title="Desactivar Equipo"]')

    await page.fill('#toggle-reason', 'Incumplimiento de términos contractuales')
    await page.click('button:has-text("Desactivar")')

    await expect(page.locator('text=Estatus del equipo actualizado.')).toBeVisible()
    expect(toggleRpcCalled).toBe(true)
  })

  test('staff member belonging to an inactive team is redirected to /equipo-inactivo', async ({ page }) => {
    // Session of staff belonging to an inactive club
    await page.addInitScript((session) => {
      window.localStorage.setItem('sb-test-auth-token', JSON.stringify(session))
    }, clubAdminSession)

    await page.route('**/rest/v1/staff_members*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          {
            id: 'staff-club-inactive-01',
            user_id: 'club-admin-user-01',
            role: 'staff',
            active: true,
            team_id: 'b0000000-0000-0000-0000-000000000002', // Cocodrilos (inactive)
            team: {
              id: 'b0000000-0000-0000-0000-000000000002',
              name: 'Cocodrilos de Caracas',
              status: 'inactive',
            },
          },
        ]),
      })
    })

    await page.goto('/staff/cola')
    await expect(page).toHaveURL(/\/equipo-inactivo/)
    await expect(page.locator('text=Membresía del Club Suspendida o Inactiva')).toBeVisible()
  })
})
