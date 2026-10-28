// A menu longer than the room below its button: DataSync's Create… menu has 26 items. Every item must
// be on screen or reachable by scrolling the menu, so the last one opens its form like the first.
import { test, expect } from './helpers.mjs';

for (const height of [900, 600]) {
  test(`every item of a long menu can be clicked in a ${height}px window`, async ({ page }) => {
    await page.setViewportSize({ width: 1440, height });
    await page.goto('/_pogi/resources/datasync');
    await page.getByRole('button', { name: 'Create…' }).click();
    const menu = page.locator('#menu');
    await expect(menu).toBeVisible();
    expect(await menu.locator('[role=menuitem]').count()).toBeGreaterThan(20);
    const box = await menu.boundingBox();
    expect(box.y).toBeGreaterThanOrEqual(0);
    expect(box.y + box.height).toBeLessThanOrEqual(height);
    await menu.locator('[role=menuitem]').last().click({ timeout: 5_000 });
    await expect(page.locator('#drawer')).toBeVisible();
  });
}
