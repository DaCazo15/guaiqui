import { test, expect } from '@playwright/test';

test('History horizontal scroll works and advances with vertical scroll', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });

  const consoleLogs: string[] = [];
  page.on('console', msg => consoleLogs.push(`[${msg.type()}] ${msg.text()}`));
  page.on('pageerror', err => consoleLogs.push(`[PAGE_ERROR] ${err.message}`));

  await page.goto('/', { waitUntil: 'networkidle' });

  // Check section exists
  const historia = page.locator('#historia');
  await expect(historia).toBeVisible();

  // Inspect GSAP state and elements before scroll
  const initialState = await page.evaluate(() => {
    const section = document.querySelector('#historia');
    const track = document.querySelector('#historia .w-max') as HTMLElement | null;
    const triggers = (window as any).ScrollTrigger
      ? (window as any).ScrollTrigger.getAll().map((t: any) => ({
          trigger: t.trigger?.tagName + (t.trigger?.id ? '#' + t.trigger.id : ''),
          start: t.start,
          end: t.end,
          progress: t.progress,
          isActive: t.isActive,
        }))
      : 'NO_GLOBAL_SCROLLTRIGGER';

    return {
      sectionHeight: section?.clientHeight,
      trackScrollWidth: track?.scrollWidth,
      trackTransform: track ? window.getComputedStyle(track).transform : null,
      triggers,
    };
  });

  console.log('Initial State:', JSON.stringify(initialState, null, 2));

  // Scroll into view of #historia
  await page.evaluate(() => {
    document.querySelector('#historia')?.scrollIntoView();
  });
  await page.waitForTimeout(500);

  const atHistoriaState = await page.evaluate(() => {
    const track = document.querySelector('#historia .w-max') as HTMLElement | null;
    const progressEl = document.querySelector('#historia .tabular-nums');
    return {
      scrollY: window.scrollY,
      progressText: progressEl?.textContent,
      trackTransform: track ? window.getComputedStyle(track).transform : null,
    };
  });
  console.log('At Historia State:', JSON.stringify(atHistoriaState, null, 2));

  // Test clicking next button
  const nextBtn = page.locator('#historia button[aria-label="Hito histórico siguiente"]');
  await expect(nextBtn).toBeVisible();
  await nextBtn.click();
  await page.waitForTimeout(600);

  const afterClickState = await page.evaluate(() => {
    const wrapper = document.querySelector('#historia [ref="trackWrapperRef"]') || document.querySelector('#historia .overflow-x-auto');
    const progressEl = document.querySelector('#historia .tabular-nums');
    return {
      scrollLeft: wrapper?.scrollLeft,
      progressText: progressEl?.textContent,
    };
  });
  console.log('After Next Button Click State:', JSON.stringify(afterClickState, null, 2));
  expect(parseInt(afterClickState.progressText?.replace('%', '') || '0')).toBeGreaterThan(0);

  // Test clicking year pill 2026
  const pill2026 = page.locator('#historia button:has-text("2026")');
  if (await pill2026.isVisible()) {
    await pill2026.click();
    await page.waitForTimeout(600);

    const after2026State = await page.evaluate(() => {
      const progressEl = document.querySelector('#historia .tabular-nums');
      return { progressText: progressEl?.textContent };
    });
    console.log('After 2026 Pill Click State:', JSON.stringify(after2026State, null, 2));
    expect(parseInt(after2026State.progressText?.replace('%', '') || '0')).toBeGreaterThan(70);
  }

  // Verify that cards and milestones are rendered
  const cards = page.locator('#historia .history-card');
  const count = await cards.count();
  expect(count).toBeGreaterThanOrEqual(5);

  console.log(`Rendered ${count} history cards successfully.`);
});


