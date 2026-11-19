// Local test server for the Flutter web build.
//
// The Grid server sets a same-site login cookie, so the app has to be loaded
// from the same address as the API. This serves `build/web` and forwards
// /api and /ws to the real server, so you can try the app on localhost:
//
//   flutter build web
//   node tool/dev_proxy.mjs                 # http://localhost:8080
//   REMOTE=https://other.host PORT=9000 node tool/dev_proxy.mjs
import http from 'node:http';
import https from 'node:https';
import tls from 'node:tls';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REMOTE = new URL(process.env.REMOTE ?? 'https://saarthi-voice.duckdns.org');
const PORT = Number(process.env.PORT ?? 8080);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../build/web');
const TYPES = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.css': 'text/css', '.json': 'application/json', '.png': 'image/png',
  '.ico': 'image/x-icon', '.wasm': 'application/wasm', '.svg': 'image/svg+xml',
  '.otf': 'font/otf', '.ttf': 'font/ttf', '.woff2': 'font/woff2',
};
const proxied = (url) => url.startsWith('/api/') || url.startsWith('/ws/');

const server = http.createServer((req, res) => {
  if (proxied(req.url)) {
    const up = https.request(
      { host: REMOTE.host, path: req.url, method: req.method,
        headers: { ...req.headers, host: REMOTE.host, origin: REMOTE.origin } },
      (r) => {
        const headers = { ...r.headers };
        if (headers['set-cookie']) {
          // localhost is plain http: drop what a browser would refuse there.
          headers['set-cookie'] = headers['set-cookie'].map((c) =>
            c.replace(/;\s*secure/gi, '').replace(/;\s*domain=[^;]*/gi, ''));
        }
        res.writeHead(r.statusCode ?? 502, headers);
        r.pipe(res);
      },
    );
    up.on('error', () => { res.writeHead(502); res.end('upstream error'); });
    req.pipe(up);
    return;
  }
  let file = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(ROOT, 'index.html');
  }
  res.writeHead(200, { 'content-type': TYPES[path.extname(file)] ?? 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});

// WebSocket: open a TLS connection to the real server and pipe bytes both ways.
server.on('upgrade', (req, socket, head) => {
  if (!proxied(req.url)) return socket.destroy();
  const up = tls.connect({ host: REMOTE.hostname, port: 443, servername: REMOTE.hostname }, () => {
    const headers = { ...req.headers, host: REMOTE.host, origin: REMOTE.origin };
    let raw = `${req.method} ${req.url} HTTP/1.1\r\n`;
    for (const [k, v] of Object.entries(headers)) raw += `${k}: ${v}\r\n`;
    up.write(raw + '\r\n');
    if (head?.length) up.write(head);
    socket.pipe(up);
    up.pipe(socket);
  });
  up.on('error', () => socket.destroy());
  socket.on('error', () => up.destroy());
});

server.listen(PORT, () => console.log(`Grid web on http://localhost:${PORT}  ->  ${REMOTE.origin}`));
