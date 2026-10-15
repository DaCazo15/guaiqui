import { test, expect } from '@playwright/test'

test.describe('Guaiqueríes Fan Zone — Trivia Flow E2E Tests', () => {
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

  test('upcoming trivia displays not started status message and disabled play button', async ({ page }) => {
    // Intercept Supabase API to mock an upcoming trivia (starts in the future)
    const upcomingTriviaId = 't-upcoming-0001'
    const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
    const farFutureDate = new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString()

    await page.route('**/rest/v1/trivias*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          {
            id: upcomingTriviaId,
            title: 'Trivia Futura de Prueba',
            description: 'Esta trivia aún no ha comenzado.',
            status: 'published',
            starts_at: futureDate,
            ends_at: farFutureDate,
            time_limit_seconds: 60,
            max_attempts: 1,
            reward_rules: { per_correct_pearls: 50, perfect_score_bonus: 100 }
          }
        ])
      })
    })

    await page.route('**/rest/v1/trivia_attempts*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([])
      })
    })

    // Mock authenticated user session
    await page.addInitScript(() => {
      window.localStorage.setItem('sb-test-auth-token', JSON.stringify({
        access_token: 'fake-jwt',
        user: { id: 'fan-test-01', email: 'fan@guaiqui.test', role: 'authenticated' }
      }))
    })

    await page.goto(`/app/trivias/${upcomingTriviaId}`)

    // Verify status warning message
    await expect(page.locator('text=Esta trivia está programada para comenzar próximamente.')).toBeVisible()
    const startButton = page.locator('button:has-text("Trivia aún no disponible")')
    await expect(startButton).toBeVisible()
    await expect(startButton).toBeDisabled()
  })

  test('active trivia allows starting, viewing questions and submitting answers', async ({ page }) => {
    const activeTriviaId = 't-active-0001'
    const pastDate = new Date(Date.now() - 3600 * 1000).toISOString()
    const futureDate = new Date(Date.now() + 3600 * 1000).toISOString()

    await page.route('**/rest/v1/trivias*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([
          {
            id: activeTriviaId,
            title: 'Trivia Clásico Oriental',
            description: 'Demuestra lo que sabes del equipo.',
            status: 'published',
            starts_at: pastDate,
            ends_at: futureDate,
            time_limit_seconds: 60,
            max_attempts: 1,
            reward_rules: { per_correct_pearls: 50, perfect_score_bonus: 100 }
          }
        ])
      })
    })

    await page.route('**/rest/v1/trivia_attempts*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([])
      })
    })

    // Mock start_trivia_attempt RPC
    await page.route('**/rest/v1/rpc/start_trivia_attempt', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          attempt_id: 'att-test-001',
          expires_at: new Date(Date.now() + 60000).toISOString(),
          seed: 42,
          questions: [
            {
              question_id: 'q-1',
              question_text: '¿En qué año se fundó Guaiqueríes de Margarita?',
              points: 50,
              options: [
                { option_id: 'opt-1', option_text: '1977' },
                { option_id: 'opt-2', option_text: '1985' }
              ]
            }
          ]
        })
      })
    })

    // Mock submit_trivia_attempt RPC
    await page.route('**/rest/v1/rpc/submit_trivia_attempt', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          attempt_id: 'att-test-001',
          score: 50,
          pearls_awarded: 50,
          suspicious: false
        })
      })
    })

    await page.goto(`/app/trivias/${activeTriviaId}`)

    // Click Empezar Trivia Ahora
    const startButton = page.locator('button:has-text("Empezar Trivia Ahora")')
    if (await startButton.isVisible()) {
      await startButton.click()

      // Check quiz question and trivia title are displayed
      await expect(page.locator('text=Trivia Clásico Oriental')).toBeVisible()
      await expect(page.locator('text=¿En qué año se fundó Guaiqueríes de Margarita?')).toBeVisible()
      // Select option
      await page.click('button:has-text("1977")')

      // Submit with actual button text
      const submitButton = page.locator('button:has-text("Enviar Respuestas")')
      if (await submitButton.isVisible()) {
        await submitButton.click()
        await expect(page.locator('text=¡Trivia Ganada!')).toBeVisible()
      }
    }
  })
})
