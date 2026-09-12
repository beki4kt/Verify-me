import { writeFile } from 'node:fs/promises';

const [
  port = '9233',
  output = 'chekmi-iphone-flow.png',
  action = 'connect',
] = process.argv.slice(2);
const targets = await fetch(`http://127.0.0.1:${port}/json/list`).then((value) =>
  value.json(),
);
const target = targets.find((item) => item.type === 'page');
if (!target) throw new Error('No Chrome page target is available.');

const socket = new WebSocket(target.webSocketDebuggerUrl);
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
  if (message.method === 'Runtime.exceptionThrown') {
    diagnostics.push(
      message.params.exceptionDetails?.exception?.description ??
        message.params.exceptionDetails?.text,
    );
  }
  if (
    message.method === 'Runtime.consoleAPICalled' &&
    ['error', 'warning'].includes(message.params.type)
  ) {
    diagnostics.push(
      message.params.args
        .map((argument) => argument.value ?? argument.description ?? '')
        .join(' '),
    );
  }
});

await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true });
  socket.addEventListener('error', reject, { once: true });
});

const wait = (milliseconds) =>
  new Promise((resolve) => setTimeout(resolve, milliseconds));
const tap = async (x, y) => {
  await send('Input.dispatchMouseEvent', {
    type: 'mousePressed',
    x,
    y,
    button: 'left',
    clickCount: 1,
  });
  await send('Input.dispatchMouseEvent', {
    type: 'mouseReleased',
    x,
    y,
    button: 'left',
    clickCount: 1,
  });
  await wait(250);
};

await send('Runtime.enable');
await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride', {
  width: 390,
  height: 844,
  deviceScaleFactor: 1,
  mobile: true,
  screenWidth: 390,
  screenHeight: 844,
});
await send('Emulation.setTouchEmulationEnabled', { enabled: true });
if (action === 'connect') {
  await send('Page.reload', { ignoreCache: true });
  await wait(6000);
  // The provisioning field and primary action in the 390 × 844 layout.
  await tap(195, 514);
  await send('Input.insertText', { text: 'MESOB-DEMO' });
  await tap(195, 576);
  await wait(7000);
} else if (action === 'language') {
  await send('Page.reload', { ignoreCache: true });
  await wait(5000);
  await tap(285, 22);
  await wait(2000);
} else if (action === 'appearance') {
  await send('Page.reload', { ignoreCache: true });
  await wait(5000);
  await tap(351, 22);
  await wait(2000);
} else if (action === 'admin') {
  await send('Page.reload', { ignoreCache: true });
  await wait(5000);
  await tap(78, 286);
  await wait(7000);
} else if (action === 'cashier') {
  await send('Page.reload', { ignoreCache: true });
  await wait(5000);
  await tap(195, 286);
  await wait(7000);
} else if (action === 'waiter') {
  await send('Page.reload', { ignoreCache: true });
  await wait(5000);
  await tap(312, 286);
  await wait(7000);
} else if (action === 'team') {
  await tap(195, 814);
  await wait(3000);
} else if (action === 'manage') {
  await tap(325, 814);
  await wait(3000);
}

const screenshot = await send('Page.captureScreenshot', {
  format: 'png',
  captureBeyondViewport: false,
});
await writeFile(output, Buffer.from(screenshot.data, 'base64'));

const location = await send('Runtime.evaluate', {
  expression: 'location.href',
  returnByValue: true,
});
process.stdout.write(
  `${JSON.stringify({ url: location.result.value, diagnostics }, null, 2)}\n`,
);
socket.close();
