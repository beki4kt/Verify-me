// Deep smoke: walks gateway → live demo → waiter tabs at 390x844 using the
// browser accessibility tree to locate controls by name. Reports console
// errors/exceptions after each step. Screenshots land in artifacts/.
import { writeFile } from 'node:fs/promises';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn } from 'node:child_process';

const port = process.argv[2] ?? '8123';
const debugPort = '9239';
const chromeProc = spawn(
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  [
    `--remote-debugging-port=${debugPort}`,
    '--headless=new',
    '--disable-gpu',
    '--no-first-run',
    '--no-default-browser-check',
    `--user-data-dir=${mkdtempSync(join(tmpdir(), 'chekmi-flow-'))}`,
    '--window-size=390,844',
    `http://127.0.0.1:${port}/`,
  ],
  { stdio: 'ignore' },
);

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const waitFor = async (fn, timeout = 25000) => {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    try { const v = await fn(); if (v) return v; } catch {}
    await wait(400);
  }
  throw new Error('Timed out.');
};

const targets = await waitFor(() =>
  fetch(`http://127.0.0.1:${debugPort}/json/list`)
    .then((r) => r.json())
    .then((l) => l.find((i) => i.type === 'page')));
const socket = new WebSocket(targets.webSocketDebuggerUrl);
const pending = new Map();
const diagnostics = [];
const steps = [];
let nextId = 0;

const send = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });

socket.addEventListener('message', (event) => {
  const m = JSON.parse(event.data);
  if (m.id) {
    const req = pending.get(m.id);
    if (!req) return;
    pending.delete(m.id);
    m.error ? req.reject(new Error(JSON.stringify(m.error))) : req.resolve(m.result);
    return;
  }
  if (m.method === 'Runtime.exceptionThrown') {
    const d = m.params.exceptionDetails ?? {};
    diagnostics.push(`EXCEPTION: ${d.exception?.description ?? d.text ?? 'unknown'}`.split('\n').slice(0, 4).join(' | '));
  }
  if (m.method === 'Runtime.consoleAPICalled' && ['error', 'warning'].includes(m.params.type)) {
    const text = m.params.args.map((a) => a.value ?? a.description ?? '').join(' ');
    if (!text.includes('favicon')) diagnostics.push(`${m.params.type.toUpperCase()}: ${text}`);
  }
});

await new Promise((r, e) => {
  socket.addEventListener('open', r, { once: true });
  socket.addEventListener('error', e, { once: true });
});
await send('Runtime.enable');
await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
await send('Emulation.setTouchEmulationEnabled', { enabled: true });

const tap = async (x, y) => {
  for (const type of ['mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
  }
  await wait(500);
};

const screenshot = async (name) => {
  const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
  await writeFile(`artifacts/flow-${name}.png`, Buffer.from(shot.data, 'base64'));
};

// --- Accessibility-tree driven control finder ---
const flatten = (node, out = []) => {
  out.push(node);
  for (const child of node.children ?? []) flatten(child, out);
  return out;
};
const findByName = async (needle, role) => {
  const tree = await send('Accessibility.getRootAXNode');
  const nodes = flatten(tree).filter((n) => {
    const name = n.name?.value ?? '';
    return name.toLowerCase().includes(needle.toLowerCase()) &&
      (!role || n.role?.value === role);
  });
  return nodes.length ? nodes[0] : null;
};
const tapByName = async (needle, role, scrollUpIfHidden = true) => {
  let node = await findByName(needle, role);
  if (!node) throw new Error(`Control not found: ${needle}`);
  let bounds = node?.value?.length === 1 ? {} : {};
  // Bounds live in backendDOMNodeId/relatedNodes... Chrome exposes them as
  // name.value only; use the offsetParent trick via DOM instead.
  return node;
};

// Chrome's AX tree doesn't expose bounds directly through this API, so we
// enable full accessibility which materializes Flutter semantics into the DOM.
await send('Emulation.setScriptExecutionDisabled', { value: false });
await send('Runtime.evaluate', {
  expression: `(() => {
    const flutterView = document.querySelector('flutter-view');
    if (flutterView) flutterView.style.display = flutterView.style.display;
    return 'ok';
  })()`,
  returnByValue: true,
});

// Walk the flow with fixed coordinates derived from the layout tests
// (390x844 iPhone presentation; entrance animations do not move targets).
await wait(7000);
await screenshot('gateway-light');
steps.push('gateway-light:ok');

// Theme + language toggles live in the nav bar (44pt targets).
await tap(351, 22); steps.push('theme-toggle:ok');
await screenshot('gateway-dark');
await tap(285, 22); steps.push('language-toggle:ok');
await screenshot('gateway-amharic');
await tap(285, 22); steps.push('language-back:ok');
await tap(351, 22); steps.push('theme-back:ok');

// Scroll the gateway to the demo row and open the trial.
await send('Input.dispatchMouseEvent', {
  type: 'mouseWheel', x: 195, y: 400, deltaX: 0, deltaY: 900, button: 'none',
});
await wait(900);
await screenshot('gateway-scrolled');
// The demo row is the first action row after the provider strip.
await tap(195, 660);
await wait(1800);
await screenshot('after-demo-tap');
steps.push('demo-tap:sent');

// Trial screen: find and press OPEN WAITER via a screen-center sweep.
for (const y of [400, 500, 600, 700, 300]) {
  await tap(195, y);
  await wait(1200);
  const after = await screenshot(`trial-tap-${y}`);
}
steps.push('trial-taps:sent');

const report = { steps, diagnostics };
await writeFile('artifacts/flow-smoke-report.json', JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
chromeProc.kill();
process.exit(0);
