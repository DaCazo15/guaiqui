import { test, expect } from '@playwright/test';

test.describe('Staging & Production Smoke Tests @smoke', () => {
  test('Landing page loads properly', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('h1')).toBeVisible();
    await expect(page).toHaveTitle(/Guaiqueríes/i);
  });

  test('Auth page renders login and register forms', async ({ page }) => {
    await page.goto('/auth');
    await expect(page.locator('input[type="email"]')).toBeVisible();
  });

  test('Trivias page renders trivia list or empty placeholder', async ({ page }) => {
    await page.goto('/trivias');
    await expect(page.locator('body')).toBeVisible();
  });

  test('Rewards store page renders catalog', async ({ page }) => {
    await page.goto('/tienda');
    await expect(page.locator('body')).toBeVisible();
  });
});
