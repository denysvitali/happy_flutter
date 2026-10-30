// Captures screenshot-gallery scenes with Playwright.
//
//   node capture.mjs --url http://127.0.0.1:8765 --out <dir> \
//     [--scenes a,b] [--themes dark,light] [--desktop sessions-list,chat-working]
//
// Phone shots: 390x844 @3x -> <out>/<scene>-<theme>.png
// Desktop shots: 1280x800 @1x -> <out>/<scene>-<theme>-desktop.png
// Each page waits for `window.__sceneReady` (set by main.dart) and fails the
// scene on `window.__sceneError` or a timeout; page/console errors are
// listed under each result.
import { mkdirSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join } from 'node:path';

// CommonJS require honours NODE_PATH (ESM imports do not), so playwright can
// live outside this repo.
const { chromium } = createRequire(import.meta.url)('playwright');

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 && i + 1 < process.argv.length ? process.argv[i + 1] : fallback;
}

const baseUrl = arg('url', 'http://127.0.0.1:8765');
const outDir = arg('out', './shots');
const themes = arg('themes', 'dark,light').split(',').filter(Boolean);
const desktopArg = arg('desktop', 'sessions-list,chat-working');
const desktopScenes = desktopArg === 'none' ? [] : desktopArg.split(',');
const timeoutMs = Number(arg('timeout', '45000'));
const settleMs = Number(arg('settle', '400'));
mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch({
  args: ['--no-sandbox', '--disable-dev-shm-usage'],
});

async function listScenes() {
  const page = await browser.newPage();
  await page.goto(`${baseUrl}/?scene=__list__`);
  await page.waitForFunction(() => window.__sceneReady === true, null, {
    timeout: timeoutMs,
  });
  const keys = await page.evaluate(() => window.__scenes);
  await page.close();
  return keys.split(',');
}

const scenes = arg('scenes', '') ? arg('scenes').split(',') : await listScenes();

async function shoot(scene, theme, viewport, scale, file) {
  const context = await browser.newContext({
    viewport,
    deviceScaleFactor: scale,
    colorScheme: theme === 'light' ? 'light' : 'dark',
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(`console: ${m.text()}`);
  });
  const started = Date.now();
  let status = 'ok';
  try {
    await page.goto(`${baseUrl}/?scene=${scene}&theme=${theme}`);
    await page.waitForFunction(
      () => window.__sceneReady === true || window.__sceneError,
      null,
      { timeout: timeoutMs },
    );
    const sceneError = await page.evaluate(() => window.__sceneError);
    if (sceneError) status = `sceneError: ${sceneError}`;
    await page.waitForTimeout(settleMs);
    await page.screenshot({ path: file });
  } catch (e) {
    status = `failed: ${e.message.split('\n')[0]}`;
    await page.screenshot({ path: file }).catch(() => {});
  }
  await context.close();
  const ms = Date.now() - started;
  return { scene, theme, file, status, ms, errors: errors.slice(0, 5) };
}

const results = [];
for (const scene of scenes) {
  for (const theme of themes) {
    const phone = join(outDir, `${scene}-${theme}.png`);
    results.push(await shoot(scene, theme, { width: 390, height: 844 }, 3, phone));
    if (desktopScenes.includes(scene)) {
      const desk = join(outDir, `${scene}-${theme}-desktop.png`);
      results.push(
        await shoot(scene, theme, { width: 1280, height: 800 }, 1, desk),
      );
    }
  }
}
await browser.close();

for (const r of results) {
  console.log(`${r.status === 'ok' ? 'OK  ' : 'FAIL'} ${r.file} (${r.ms}ms) ${r.status === 'ok' ? '' : r.status}`);
  for (const e of r.errors) console.log(`       ${e.slice(0, 200)}`);
}
writeFileSync(join(outDir, 'capture-report.json'), JSON.stringify(results, null, 2));
process.exit(results.some((r) => r.status !== 'ok') ? 1 : 0);
