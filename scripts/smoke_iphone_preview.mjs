// Headless-Chrome smoke drive of the CHEKMI iPhone web preview.
// Loads the built app at 390x844, walks the core surfaces (gateway light/dark,
// Amharic toggle, staff login), and reports console errors/exceptions.
// Usage: node scripts/smoke_iphone_preview.mjs <port>
import { writeFile } from 'node:fs/promises';

const port = process.argv[2] ?? '8123';
const debugPort = '9237';
const chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';

const { spawn } = await import('node:child_process');
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const profileDir = mkdtempSync(join(tmpdir(), 'chekmi-chrome-'));
const chromeProc = spawn(
  chrome,
  [
    `--remote-debugging-port=${debugPort}`,
    '--headless=new',
    '--disable-gpu',
    '--no-first-run',
    '--no-default-browser-check',
    `--user-data-dir=${profileDir}`,
    '--window-size=390,844',
    `http://127.0.0.1:${port}/`,
  ],
  { stdio: 'ignore', detached: false },
);

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const waitFor = async (fn, timeout = 20000) => {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    try {
      const value = await fn();
      if (value) return value;
    } catch {}
    await wait(300);
  }
  throw new Error('Timed out waiting for condition.');
};

const targets = await waitFor(() =>
  fetch(`http://127.0.0.1:${debugPort}/json/list`)
    .then((r) => r.json())
    .then((list) => list.find((item) => item.type === 'page')),
);
const socket = new WebSocket(targets.webSocketDebuggerUrl);
const pending = new Map();
const diagnostics = [];
let nextId = 0;

const send = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });

socket.addEventListener('message', (event) => {
  const message = JSON.parse(event.data);
  if (message.id) {
    const request = pending.get(message.id);
    if (!request) return;
    pending.delete(message.id);
    if (message.error) request.reject(new Error(JSON.stringify(message.error)));
    else request.resolve(message.result);
    return;
  }
  const t0 = Date.now();
  if (message.method === 'Runtime.exceptionThrown') {
    const d = message.params.exceptionDetails ?? {};
    diagnostics.push(
      `EXCEPTION@${Date.now() - t0}ms line=${d.lineNumber} col=${d.columnNumber}: ` +
        (d.exception?.description ?? d.text ?? 'unknown'),
    );
  }
  if (message.method === 'Runtime.consoleAPICalled') {
    const text = message.params.args
      .map((a) => a.value ?? a.description ?? '')
      .join(' ');
    if (message.params.type === 'error' || message.params.type === 'warning') {
      diagnostics.push(`${message.params.type.toUpperCase()}: ${text}`);
    } else if (text.includes('overflow') || text.includes('Exception')) {
      diagnostics.push(`LOG: ${text}`);
    }
  }
});

await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true });
  socket.addEventListener('error', reject, { once: true });
});

const tap = async (x, y) => {
  for (const type of ['mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent', {
      type, x, y, button: 'left', clickCount: 1,
    });
  }
  await wait(400);
};

const screenshot = async (name) => {
  const shot = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: false,
  });
  await writeFile(`artifacts/preview-${name}.png`, Buffer.from(shot.data, 'base64'));
};

await send('Runtime.enable');
await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', {
  width: 390, height: 844, deviceScaleFactor: 2, mobile: true,
});
await send('Emulation.setTouchEmulationEnabled', { enabled: true });

const report = { steps: [], diagnostics };

// 1. Gateway (light).
await wait(6000);
await screenshot('gateway-light');
report.steps.push('gateway-light');

// 2. Theme toggle (dark).
await tap(351, 22);
await wait(600);
await screenshot('gateway-dark');
report.steps.push('gateway-dark');

// 3. Language toggle (Amharic).
await tap(285, 22);
await wait(600);
await screenshot('gateway-amharic-dark');
report.steps.push('gateway-amharic-dark');

// Back to English + light.
await tap(285, 22);
await wait(500);
await tap(351, 22);
await wait(500);

// 4. Staff login (via change-workspace back arrow on gateway).
await tap(28, 40);
await wait(800);
await screenshot('staff-login');
report.steps.push('staff-login');

const location = await send('Runtime.evaluate', {
  expression: 'location.href',
  returnByValue: true,
});
report.finalUrl = location.result.value;
report.diagnostics = diagnostics.filter(
  (line) =>
    !line.includes('Download the React DevTools') &&
    !line.includes('go/index') &&
    !line.toLowerCase().includes('favicon'),
);

await writeFile(
  'artifacts/preview-smoke-report.json',
  JSON.stringify(report, null, 2),
);
console.log(JSON.stringify(report, null, 2));
chromeProc.kill();
process.exit(0);
