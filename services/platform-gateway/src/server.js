import http from 'node:http';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';

function send(res, status, body, headers = {}) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', ...headers });
  res.end(JSON.stringify(body));
}

function redirect(res, location) {
  res.writeHead(303, { location });
  res.end();
}

function createServer({ port = Number(process.env.PORT || 8787), newApiBaseUrl = process.env.NEW_API_BASE_URL || '', canvasCallbackUrl, canvasAppUrl = process.env.CANVAS_APP_URL || '' } = {}) {
  const callbackUrl = canvasCallbackUrl || `http://127.0.0.1:${port}/sso/callback`;
  const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || '127.0.0.1'}`);
  if (req.method === 'GET' && url.pathname === '/health') {
    return send(res, 200, { status: 'ok', service: 'platform-gateway', newApiConfigured: Boolean(newApiBaseUrl) });
  }
  if (req.method === 'GET' && url.pathname === '/canvas/login') {
    if (!newApiBaseUrl) return send(res, 503, { error: { code: 'NEW_API_NOT_CONFIGURED', message: 'NEW_API_BASE_URL is required' } });
    const state = randomBytes(24).toString('base64url');
    const authorize = new URL('/internal/v1/sso/authorize', newApiBaseUrl);
    authorize.searchParams.set('audience', 'canvas');
    authorize.searchParams.set('state', state);
    authorize.searchParams.set('redirect_uri', callbackUrl);
    return redirect(res, authorize.toString());
  }
  if (req.method === 'GET' && url.pathname === '/canvas') {
    if (canvasAppUrl) return redirect(res, canvasAppUrl);
    return redirect(res, '/canvas/login');
  }
  return send(res, 404, { error: { code: 'NOT_FOUND', message: 'route not found' } });
  });
  return server;
}

const isMainModule = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
const server = isMainModule ? createServer() : null;
if (server) server.listen(Number(process.env.PORT || 8787), '127.0.0.1');

export { createServer, server };
