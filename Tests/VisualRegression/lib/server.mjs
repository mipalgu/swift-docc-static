// A minimal static file server for a generated documentation site.
//
// Serving over HTTP (rather than file://) gives the pages one origin, which the
// embedded navigation sidebar and the JavaScript renderer both need.
import { createServer } from 'node:http';
import { createReadStream, statSync } from 'node:fs';
import { extname, join, normalize } from 'node:path';

const TYPES = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.ico': 'image/x-icon', '.woff': 'font/woff', '.woff2': 'font/woff2', '.txt': 'text/plain; charset=utf-8',
};

/**
 * Serves `root` on `port` (0 picks a free port).
 * Resolves to `{ base, close }` where `base` is the site's base URL.
 *
 * `options.delay`, when given, is called with the path of every request and returns
 * the number of milliseconds to wait before answering it, which lets a check make a
 * resource arrive late.
 */
export function serve(root, port = 0, { delay } = {}) {
  const server = createServer(async (request, response) => {
    let path = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    let file = normalize(join(root, path));
    if (!file.startsWith(normalize(root))) { response.writeHead(403).end(); return; }
    try {
      if (statSync(file).isDirectory()) file = join(file, 'index.html');
      statSync(file);
    } catch {
      response.writeHead(404).end();
      return;
    }
    const wait = delay ? delay(path) : 0;
    if (wait > 0) await new Promise((done) => setTimeout(done, wait));
    response.writeHead(200, { 'Content-Type': TYPES[extname(file)] || 'application/octet-stream' });
    createReadStream(file).pipe(response);
  });
  return new Promise((resolve) => {
    server.listen(port, '127.0.0.1', () => {
      const { port: actual } = server.address();
      resolve({ base: `http://127.0.0.1:${actual}`, close: () => new Promise((done) => server.close(done)) });
    });
  });
}
