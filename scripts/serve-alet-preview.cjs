const http = require('node:http');
const https = require('node:https');
const fs = require('node:fs');
const path = require('node:path');
const phonePreview = process.argv.includes('--iphone');
const root = path.resolve(__dirname, phonePreview ? '../build/alet-iphone-web' : '../build/alet-live-web');
const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json', '.css': 'text/css', '.wasm': 'application/wasm',
  '.png': 'image/png', '.svg': 'image/svg+xml', '.woff2': 'font/woff2',
  '.ttf': 'font/ttf', '.ico': 'image/x-icon',
};
if (!fs.existsSync(path.join(root, 'index.html'))) throw new Error(`Build ${root} first.`);
http.createServer((req, res) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); }
  catch { res.writeHead(400).end(); return; }
  // Fixed HTTPS upstream for the LAN-only phone preview. No caller-selected
  // host, credential storage, request logging, or certificate bypass.
  if (phonePreview && (pathname.startsWith('/api/') || ['/ready', '/health', '/connectivity'].includes(pathname))) {
    const headers = {};
    for (const name of ['authorization', 'content-type', 'content-length', 'accept', 'x-api-key']) {
      if (req.headers[name]) headers[name] = req.headers[name];
    }
    const upstream = https.request({
      hostname: 'chekmi.app.aletcloud.com', port: 443, path: req.url,
      method: req.method, headers, rejectUnauthorized: true,
    }, reply => {
      const responseHeaders = {'cache-control': 'no-store'};
      for (const name of ['content-type', 'retry-after', 'x-request-id']) {
        if (reply.headers[name]) responseHeaders[name] = reply.headers[name];
      }
      res.writeHead(reply.statusCode || 502, responseHeaders);
      reply.on('error', () => res.destroy());
      reply.pipe(res);
    });
    upstream.setTimeout(60000, () => upstream.destroy(new Error('Upstream timeout')));
    upstream.on('error', () => {
      if (res.headersSent) { res.destroy(); return; }
      res.writeHead(502, {'content-type': 'application/json'});
      res.end(JSON.stringify({success:false,code:'PREVIEW_UPSTREAM_UNAVAILABLE',error:'Cannot reach the hosted backend from this PC.'}));
    });
    req.on('aborted', () => upstream.destroy());
    res.on('close', () => { if (!res.writableEnded) upstream.destroy(); });
    req.pipe(upstream);
    return;
  }
  const target = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
  if (!target.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
  fs.stat(target, (error, stat) => {
    if (error || !stat.isFile()) { res.writeHead(404).end('Not found'); return; }
    res.writeHead(200, {
      'Content-Type': types[path.extname(target)] || 'application/octet-stream',
      'Content-Length': stat.size, 'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    if (req.method === 'HEAD') { res.end(); return; }
    const stream = fs.createReadStream(target);
    stream.on('error', () => res.destroy());
    stream.pipe(res);
  });
}).listen(8087, phonePreview ? '0.0.0.0' : '127.0.0.1', () => console.log(
  phonePreview ? 'CHEKMI iPhone preview listening on LAN port 8087; API forwarded to Alet over HTTPS.' : 'Connected CHEKMI preview: http://127.0.0.1:8087'
));
