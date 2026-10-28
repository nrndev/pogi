// Back and Forward through the console. htmx puts a page it restores from its history back without a
// target, so the console's htmx:afterSwap handlers must not assume one.
import { test, expect } from './helpers.mjs';

const pages = ['/_pogi/requests', '/_pogi/sql', '/_pogi/secrets', '/_pogi/terraform', '/_pogi/chaos', '/_pogi/connect', '/_pogi/resources/s3'];

test('Back and Forward raise no script errors', async ({ page }) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(`${page.url()}: ${e.message}`));
  await page.goto('/_pogi/');
  const home = await page.locator('h1').textContent();
  for (const p of pages) {
    await page.locator(`nav a[href="${p}"], main a[href="${p}"]`).first().click();
    await expect(page).toHaveURL(p);
    const there = await page.locator('h1').textContent();
    await page.goBack();
    await expect(page.locator('h1')).toHaveText(home);
    await page.goForward();
    await expect(page.locator('h1')).toHaveText(there);
    await page.goBack();
    await expect(page.locator('h1')).toHaveText(home);
  }
  expect(errors).toEqual([]);
});
