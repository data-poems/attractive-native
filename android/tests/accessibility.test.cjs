const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const http = require('node:http');
const { execFileSync } = require('node:child_process');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

const root = path.resolve(__dirname, '../..');
const staging = fs.mkdtempSync(path.join(os.tmpdir(), 'attractive-accessibility-'));
const results = [];
let browser;
let server;

async function assertState(page, expression, message) {
  await page.waitForFunction(expression);
  assert.ok(await page.evaluate(expression), message);
}

async function checkCompact(page, width, height) {
  const checks = [];
  await assertState(page, () => document.getElementById('sidebar').inert, 'closed menu is inert');
  await page.locator('#hamburgerBtn').focus();
  await page.keyboard.press('Tab');
  assert.equal(await page.evaluate(() => document.activeElement.id), 'canvas', 'Tab skips closed menu controls');
  assert.equal(await page.locator('.stats').getAttribute('role'), 'group');
  assert.equal(await page.locator('.stats').getAttribute('aria-live'), 'off');
  assert.equal(await page.locator('#liveAnnouncement').getAttribute('aria-live'), 'polite');
  checks.push('hidden-menu-excluded', 'stats-readable-without-live-chatter');

  if (width === 598) {
    await page.evaluate(() => {
      window.fpsMutations = 0;
      new MutationObserver(() => window.fpsMutations++).observe(document.getElementById('fpsCount'), { childList: true, characterData: true, subtree: true });
    });
    await page.waitForFunction(() => window.fpsMutations > 0);
    checks.push('visual-fps-updates-preserved');
  }
  await page.locator('#canvas').focus();
  const canvasPlaying = await page.locator('#floatingPlayPauseBtn').getAttribute('aria-pressed');
  await page.keyboard.press('Space');
  assert.notEqual(await page.locator('#floatingPlayPauseBtn').getAttribute('aria-pressed'), canvasPlaying, 'canvas Space shortcut still works');
  await page.keyboard.press('Space');
  assert.equal(await page.locator('#floatingPlayPauseBtn').getAttribute('aria-pressed'), canvasPlaying);
  checks.push('canvas-playback-shortcut-preserved');

  await page.locator('#lessonsBtn').focus();
  const playing = await page.locator('#floatingPlayPauseBtn').getAttribute('aria-pressed');
  await page.evaluate(() => {
    window.closeFocusCount = 0;
    window.targetSpaceCount = 0;
    document.getElementById('lessonsCloseBtn').addEventListener('focus', () => window.closeFocusCount++);
    document.getElementById('lessonsBtn').addEventListener('keydown', event => {
      if (event.key === ' ') window.targetSpaceCount++;
    });
  });
  await page.keyboard.press('Space');
  await assertState(page, () => document.getElementById('lessonsPanel').getAttribute('aria-modal') === 'true');
  assert.equal(await page.locator('#floatingPlayPauseBtn').getAttribute('aria-pressed'), playing, 'Space opens Lessons without toggling playback');
  assert.equal(await page.evaluate(() => document.activeElement.id), 'lessonsCloseBtn');
  assert.equal(await page.evaluate(() => window.closeFocusCount), 1, 'one focus transfer after visibility synchronization');
  assert.equal(await page.evaluate(() => window.targetSpaceCount), 1, 'control key handlers still receive Space');
  assert.equal(await page.locator('#lessonsPanel').getAttribute('role'), 'dialog');
  assert.ok(await page.locator('.floating-controls').evaluate(element => element.inert));
  assert.ok(await page.locator('#canvas').evaluate(element => element.inert));
  await page.evaluate(() => {
    window.backgroundRandomClicks = 0;
    document.getElementById('randomBtn').addEventListener('click', () => window.backgroundRandomClicks++);
  });
  await page.keyboard.press('r');
  assert.equal(await page.evaluate(() => window.backgroundRandomClicks), 0, 'modal keys do not activate background shortcuts');
  await page.keyboard.press('Shift+Tab');
  await assertState(page, () => document.activeElement.closest('#lessonsPanel') !== null);
  await page.keyboard.press('Tab');
  assert.equal(await page.evaluate(() => document.activeElement.id), 'lessonsCloseBtn', 'Tab wraps inside Lessons');
  const focusCountAfterTab = await page.evaluate(() => window.closeFocusCount);
  await page.getByRole('button', { name: /^Start lesson:/ }).first().click();
  assert.ok(await page.evaluate(() => document.activeElement.classList.contains('lesson-nav-next')), 'lesson step retains its own focus behavior');
  assert.equal(await page.evaluate(() => window.closeFocusCount), focusCountAfterTab, 'no focus theft during lesson updates');
  await page.keyboard.press('Escape');
  await assertState(page, () => document.activeElement.id === 'lessonsBtn');
  assert.ok(await page.locator('#lessonsPanel').evaluate(element => element.inert));
  assert.ok(!(await page.locator('.floating-controls').evaluate(element => element.inert)));
  checks.push('space-preserves-native-button-activation', 'lessons-isolation-tab-escape-return', 'lesson-focus-not-repeated');

  await page.locator('#equationsBtn').focus();
  await page.keyboard.press('Space');
  await assertState(page, () => document.activeElement.id === 'equationsCloseBtn');
  assert.equal(await page.locator('#equationsPanel').getAttribute('role'), 'dialog');
  await page.keyboard.press('Tab');
  assert.equal(await page.evaluate(() => document.activeElement.id), 'equationsCloseBtn');
  await page.keyboard.press('Escape');
  await assertState(page, () => document.activeElement.id === 'equationsBtn');
  checks.push('equations-isolation-tab-escape-return');

  await page.locator('#hamburgerBtn').focus();
  await page.keyboard.press('Space');
  await assertState(page, () => document.activeElement.id === 'sidebarCloseBtn');
  assert.equal(await page.locator('#sidebar').getAttribute('role'), 'dialog');
  await page.keyboard.press('Shift+Tab');
  assert.ok(await page.evaluate(() => document.activeElement.closest('#sidebar') !== null));
  await page.keyboard.press('Tab');
  assert.equal(await page.evaluate(() => document.activeElement.id), 'sidebarCloseBtn');
  await page.keyboard.press('Escape');
  await assertState(page, () => document.activeElement.id === 'hamburgerBtn');
  checks.push('menu-isolation-tab-escape-return');

  await page.locator('#hamburgerBtn').focus();
  await page.keyboard.press('Space');
  await assertState(page, () => document.activeElement.id === 'sidebarCloseBtn');
  await page.setViewportSize({ width: 1200, height: 900 });
  await assertState(page, () => document.activeElement.id === 'sidebarToggleBtn' && !document.getElementById('sidebar').inert);
  assert.equal(await page.locator('#sidebar').getAttribute('role'), 'complementary');
  await page.setViewportSize({ width, height });
  await assertState(page, () => document.activeElement.id === 'sidebarCloseBtn' && document.getElementById('canvas').inert);
  await page.keyboard.press('Escape');
  await assertState(page, () => document.activeElement.id === 'hamburgerBtn');
  checks.push('menu-resize-focus-visible');

  await page.locator('#lessonsBtn').focus();
  await page.keyboard.press('Space');
  await assertState(page, () => document.activeElement.id === 'lessonsCloseBtn');
  await page.setViewportSize({ width: 1200, height: 900 });
  await assertState(page, () => !document.getElementById('canvas').inert && !document.getElementById('sidebar').inert);
  assert.equal(await page.locator('#lessonsPanel').getAttribute('role'), 'complementary');
  assert.equal(await page.locator('#lessonsPanel').getAttribute('aria-modal'), null);
  assert.equal(await page.locator('#sidebar').getAttribute('aria-hidden'), 'false');
  await page.locator('#presetSelect').focus();
  assert.equal(await page.evaluate(() => document.activeElement.id), 'presetSelect', 'desktop background remains interactive');
  await page.setViewportSize({ width, height });
  await assertState(page, () => document.getElementById('canvas').inert && document.activeElement.id === 'lessonsCloseBtn');
  await page.keyboard.press('Escape');
  await assertState(page, () => document.activeElement.id === 'lessonsBtn');
  // The existing toolbar animates its desktop/mobile left position for 300ms.
  await page.waitForFunction(viewportWidth => {
    const bounds = document.getElementById('lessonsBtn').getBoundingClientRect();
    return bounds.x >= 0 && bounds.right <= viewportWidth;
  }, width, { timeout: 3000 });
  const bounds = await page.locator('#lessonsBtn').boundingBox();
  assert.ok(bounds.x >= 0 && bounds.x + bounds.width <= width,
    `returned toolbar focus remains visible: ${JSON.stringify({ width, height, bounds, toolbar: await page.locator('.floating-controls').evaluate(element => ({ x: element.getBoundingClientRect().x, width: element.clientWidth, scrollLeft: element.scrollLeft, scrollWidth: element.scrollWidth })) })}`);
  checks.push('desktop-resize-clears-isolation', 'compact-resize-restores-isolation', 'late-toolbar-focus-visible');
  return { width, height, checks };
}

(async () => {
  try {
    fs.mkdirSync(path.join(staging, 'scripts'));
    fs.mkdirSync(path.join(staging, 'android'));
    fs.symlinkSync(path.join(root, 'attractive-web'), path.join(staging, 'attractive-web'), 'dir');
    fs.copyFileSync(path.join(root, 'scripts/prepare-android-web.sh'), path.join(staging, 'scripts/prepare-android-web.sh'));
    for (const file of ['compact-window.css', 'accessibility.js']) fs.copyFileSync(path.join(root, 'android', file), path.join(staging, 'android', file));
    execFileSync('bash', [path.join(staging, 'scripts/prepare-android-web.sh')], { stdio: 'pipe' });
    const assets = path.join(staging, 'android/web');
    server = http.createServer((request, response) => {
      const url = new URL(request.url, 'http://localhost');
      const file = path.resolve(assets, '.' + (url.pathname === '/' || url.pathname === '/baseline' ? '/index.html' : url.pathname));
      if (!file.startsWith(assets + path.sep) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) { response.writeHead(404).end(); return; }
      const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' };
      response.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
      let data = fs.readFileSync(file);
      if (url.pathname === '/baseline') data = Buffer.from(data.toString().replace(/<script src="accessibility\.js"><\/script>/, ''));
      response.end(data);
    });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const origin = `http://127.0.0.1:${server.address().port}`;
    browser = await chromium.launch({ channel: 'chrome', headless: true });
    const baseline = await browser.newPage({ viewport: { width: 598, height: 530 } });
    await baseline.goto(origin + '/baseline');
    await baseline.locator('#lessonsBtn').focus();
    const prior = await baseline.locator('#floatingPlayPauseBtn').getAttribute('aria-pressed');
    await baseline.keyboard.press('Space');
    assert.equal(await baseline.locator('#lessonsBtn').getAttribute('aria-expanded'), 'false');
    assert.notEqual(await baseline.locator('#floatingPlayPauseBtn').getAttribute('aria-pressed'), prior);
    assert.ok(!(await baseline.locator('#sidebar').evaluate(element => element.inert)));
    results.push({ baseline: 'reproduced native-button Space interception and exposed closed menu' });
    await baseline.close();

    for (const [width, height] of [[598, 530], [372, 662], [360, 840]]) {
      const page = await browser.newPage({ viewport: { width, height } });
      const errors = [];
      const external = [];
      page.on('pageerror', error => errors.push(error.message));
      await page.route('**/*', route => {
        if (route.request().url().startsWith(origin + '/')) return route.continue();
        external.push(route.request().url());
        return route.abort();
      });
      await page.goto(origin + '/');
      results.push(await checkCompact(page, width, height));
      assert.deepEqual(errors, []);
      assert.deepEqual(external, []);
      await page.close();
    }
    const desktop = await browser.newPage({ viewport: { width: 1200, height: 900 } });
    await desktop.goto(origin + '/');
    await assertState(desktop, () => !document.getElementById('sidebar').inert);
    await desktop.locator('#sidebarToggleBtn').click();
    await assertState(desktop, () => document.getElementById('sidebar').inert);
    await desktop.locator('#sidebarToggleBtn').click();
    await assertState(desktop, () => !document.getElementById('sidebar').inert);
    await desktop.locator('#equationsBtn').focus();
    await desktop.keyboard.press('Space');
    await assertState(desktop, () => document.activeElement.id === 'equationsCloseBtn');
    assert.equal(await desktop.locator('#equationsPanel').getAttribute('role'), 'complementary');
    assert.equal(await desktop.locator('#equationsPanel').getAttribute('aria-modal'), null);
    assert.ok(!(await desktop.locator('#canvas').evaluate(element => element.inert)));
    await desktop.locator('#equationsCloseBtn').click();
    await desktop.locator('#infoBtn').focus();
    await desktop.keyboard.press('Space');
    await assertState(desktop, () => document.activeElement.id === 'modalCloseBtn' && document.getElementById('canvas').inert);
    await desktop.keyboard.press('Escape');
    await assertState(desktop, () => document.activeElement.id === 'infoBtn' && !document.getElementById('canvas').inert);
    results.push({ width: 1200, height: 900, checks: ['sidebar-collapse-focus-exclusion', 'nonmodal-panels-preserved', 'about-modal-isolation-return'] });
    console.log(JSON.stringify({ results, talkBack: 'Intentionally skipped at the user’s request; browser checks only' }, null, 2));
  } finally {
    if (browser) await browser.close();
    if (server) await new Promise(resolve => server.close(resolve));
    fs.rmSync(staging, { recursive: true, force: true });
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
