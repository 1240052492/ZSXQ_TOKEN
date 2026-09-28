import http from 'node:http';
import { fileURLToPath } from 'node:url';
import { CanvasSessionStore } from './canvas-session-store.js';
import { NewApiClient } from './new-api-client.js';
import { BillingStateMachine } from './billing-state-machine.js';

const SESSION_COOKIE = 'canvas_session';
const COOKIE_MAX_AGE = Number(process.env.COOKIE_MAX_AGE) || 28800;

function send(res, status, body, headers = {}) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', ...headers });
  res.end(JSON.stringify(body));
}

function redirect(res, location, headers = {}) {
  res.writeHead(303, { location, ...headers });
  res.end();
}

function parseCookies(header = '') {
  return Object.fromEntries(
    header.split(';')
      .map((part) => part.trim().split('='))
      .filter(([key, value]) => key && value)
      .map(([key, ...value]) => [key, value.join('=')])
  );
}

function cookie(name, value, { maxAge, clear = false } = {}) {
  const parts = [
    `${name}=${clear ? '' : encodeURIComponent(value)}`,
    'Path=/',
    'HttpOnly',
    'SameSite=Lax'
  ];
  if (process.env.NODE_ENV !== 'development') parts.push('Secure');
  if (maxAge !== undefined) parts.push(`Max-Age=${maxAge}`);
  return parts.join('; ');
}

function createServer({
  port = Number(process.env.PORT || 3001),
  newApiBaseUrl = process.env.NEW_API_BASE_URL || '',
  serviceToken = process.env.SERVICE_TOKEN || '',
  sessionStore = new CanvasSessionStore(),
  newApiClient = new NewApiClient({ baseUrl: newApiBaseUrl, serviceToken }),
  billingStateMachine = new BillingStateMachine({ newApiClient }),
} = {}) {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://${req.headers.host || '127.0.0.1'}`);
    const cookies = parseCookies(req.headers.cookie);

    // Health check
    if (req.method === 'GET' && url.pathname === '/health') {
      return send(res, 200, {
        status: 'ok',
        service: 'super-canvas-adapter',
        configured: Boolean(newApiBaseUrl && serviceToken)
      });
    }

    // SSO callback handler
    if (req.method === 'GET' && url.pathname === '/sso/callback') {
      const code = url.searchParams.get('code') || '';
      const state = url.searchParams.get('state') || '';

      if (!code || !state) {
        return send(res, 400, { error: { code: 'MISSING_PARAMETERS' } });
      }

      try {
        const result = await newApiClient.exchangeCanvasCode({ code, state });
        const session = sessionStore.create({
          userId: result.userId,
          subject: result.sessionSubject
        });

        return redirect(res, '/', {
          'set-cookie': cookie(SESSION_COOKIE, session.token, { maxAge: COOKIE_MAX_AGE })
        });
      } catch (error) {
        const status = error.status || 500;
        return send(res, status, { error: { code: error.code || 'SSO_CALLBACK_FAILED', message: error.message } });
      }
    }

    // Session status
    if (req.method === 'GET' && url.pathname === '/api/session') {
      const session = sessionStore.read(cookies[SESSION_COOKIE]);
      if (!session) {
        return send(res, 401, { error: { code: 'NOT_AUTHENTICATED' } });
      }
      return send(res, 200, {
        ok: true,
        data: {
          user_id: session.userId,
          subject: session.subject,
          expires_at: session.expiresAt
        }
      });
    }

    // Logout
    if (req.method === 'POST' && url.pathname === '/api/logout') {
      sessionStore.revoke(cookies[SESSION_COOKIE]);
      return send(res, 200, { ok: true }, {
        'set-cookie': cookie(SESSION_COOKIE, '', { maxAge: 0, clear: true })
      });
    }

    // Billing endpoints (future WP-02)
    if (req.method === 'POST' && url.pathname === '/api/billing/reserve') {
      const session = sessionStore.read(cookies[SESSION_COOKIE]);
      if (!session) {
        return send(res, 401, { error: { code: 'NOT_AUTHENTICATED' } });
      }
      // Placeholder for WP-02
      return send(res, 501, { error: { code: 'NOT_IMPLEMENTED' } });
    }

    return send(res, 404, { error: { code: 'NOT_FOUND' } });
  });

  return server;
}

const isMainModule = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
const server = isMainModule ? createServer() : null;
if (server) {
  const port = Number(process.env.PORT || 3001);
  server.listen(port, '0.0.0.0', () => {
    console.log(`Super Canvas Adapter listening on port ${port}`);
  });
}

export { createServer, server };
