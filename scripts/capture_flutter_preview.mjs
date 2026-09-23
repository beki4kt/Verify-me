import { writeFile } from 'node:fs/promises';

const [port = '9227', output = 'flutter-preview.png', waitMs = '10000'] =
  process.argv.slice(2);
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
    diagnostics.push({
      type: 'exception',
      text: message.params.exceptionDetails?.text,
      description: message.params.exceptionDetails?.exception?.description,
    });
  }
  if (message.method === 'Runtime.consoleAPICalled') {
    diagnostics.push({
      type: `console.${message.params.type}`,
      text: message.params.args
        .map((argument) => argument.value ?? argument.description ?? '')
        .join(' '),
    });
  }
});

await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true });
  socket.addEventListener('error', reject, { once: true });
});

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
await send('Page.reload', { ignoreCache: true });
await new Promise((resolve) => setTimeout(resolve, Number(waitMs)));

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
  `${JSON.stringify({
    url: location.result.value,
    diagnostics,
  }, null, 2)}\n`,
);

await send('Browser.close');
