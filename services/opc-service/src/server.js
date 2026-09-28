import http from 'node:http';
import { randomBytes, timingSafeEqual } from 'node:crypto';
import { fileURLToPath } from 'node:url';

import { OpcSessionStore } from './session-store.js';

const STATE_COOKIE = 'opc_sso_state';
const SESSION_COOKIE = 'opc_session';
const COOKIE_MAX_AGE = 8 * 60 * 60;

function send(res, status, body, headers = {}) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', ...headers });
  res.end(JSON.stringify(body));
}

function redirect(res, location, headers = {}) {
  res.writeHead(303, { location, ...headers });
  res.end();
}

function parseCookies(header = '') {
  return Object.fromEntries(header.split(';').map((part) => part.trim().split('='))
    .filter(([key, value]) => key && value)
    .map(([key, ...value]) => [key, value.join('=')]));
}

function cookie(name, value, { maxAge, clear = false } = {}) {
  const parts = [`${name}=${clear ? '' : encodeURIComponent(value)}`, 'Path=/', 'HttpOnly', 'SameSite=Lax'];
  if (process.env.NODE_ENV !== 'development') parts.push('Secure');
  if (maxAge !== undefined) parts.push(`Max-Age=${maxAge}`);
  return parts.join('; ');
}

function safeEqual(left, right) {
  const a = Buffer.from(String(left || ''));
  const b = Buffer.from(String(right || ''));
  return a.length > 0 && a.length === b.length && timingSafeEqual(a, b);
}

function parseJson(response) {
  return response.json().catch(() => null);
}

function parseOpcEnabled(payload) {
  const status = payload?.data && typeof payload.data === 'object' ? payload.data : payload;
  const raw = status?.HeaderNavModules;
  if (typeof raw === 'boolean') return raw;
  if (raw && typeof raw === 'object') {
    const opc = raw.opc;
    return typeof opc === 'boolean' ? opc : Boolean(opc?.enabled);
  }
  if (typeof raw !== 'string') return false;
  try {
    const modules = JSON.parse(raw);
    const opc = modules?.opc;
    return typeof opc === 'boolean' ? opc : Boolean(opc?.enabled);
  } catch {
    return false;
  }
}

function createServer({
  port = Number(process.env.PORT || 8890),
  newApiBaseUrl = process.env.NEW_API_BASE_URL || '',
  publicUrl = process.env.OPC_PUBLIC_URL || '',
  redirectUri = process.env.OPC_SSO_REDIRECT_URI || `${publicUrl.replace(/\/$/, '')}/sso/callback`,
  internalToken = process.env.OPC_SSO_INTERNAL_TOKEN || '',
  sessionStore = new OpcSessionStore(),
  fetchImpl = globalThis.fetch,
  opcEnabledCheck,
} = {}) {
  const baseUrl = String(newApiBaseUrl).replace(/\/$/, '');
  const callbackUrl = String(redirectUri).replace(/\/$/, '');
  const checkEnabled = opcEnabledCheck || (async () => {
    if (!baseUrl) return null;
    try {
      const response = await fetchImpl(`${baseUrl}/api/status`, { headers: { accept: 'application/json' } });
      if (!response.ok) return null;
      return parseOpcEnabled(await parseJson(response));
    } catch {
      return null;
    }
  });
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://${req.headers.host || '127.0.0.1'}`);
    const cookies = parseCookies(req.headers.cookie);

    if (req.method === 'GET' && url.pathname === '/health') {
      return send(res, 200, { ok: true, service: 'opc-service', configured: Boolean(baseUrl && callbackUrl && internalToken) });
    }

    if (req.method === 'GET' && url.pathname === '/sso/start') {
      if (!baseUrl || !callbackUrl || !internalToken) {
        return send(res, 503, { ok: false, code: 'OPC_SSO_NOT_CONFIGURED' });
      }
      const enabled = await checkEnabled();
      if (enabled === null) return send(res, 503, { ok: false, code: 'OPC_STATUS_UNAVAILABLE' });
      if (!enabled) return send(res, 404, { ok: false, code: 'OPC_DISABLED' });
      const state = randomBytes(32).toString('base64url');
      const authorize = new URL('/api/user/auth/opc/authorize', baseUrl);
      authorize.searchParams.set('audience', 'opc');
      authorize.searchParams.set('state', state);
      authorize.searchParams.set('redirect_uri', callbackUrl);
      return redirect(res, authorize.toString(), {
        'set-cookie': cookie(STATE_COOKIE, state, { maxAge: 300 }),
      });
    }

    if (req.method === 'GET' && url.pathname === '/sso/callback') {
      const code = url.searchParams.get('code') || '';
      const state = url.searchParams.get('state') || '';
      if (!safeEqual(state, cookies[STATE_COOKIE]) || !code) {
        return send(res, 400, { ok: false, code: 'OPC_SSO_STATE_INVALID' });
      }
      let response;
      try {
        response = await fetchImpl(`${baseUrl}/internal/v1/opc/sso/exchange`, {
          method: 'POST',
          headers: { 'content-type': 'application/json', 'X-OPC-SSO-Token': internalToken },
          body: JSON.stringify({ code, audience: 'opc' }),
        });
      } catch {
        return send(res, 502, { ok: false, code: 'OPC_SSO_UPSTREAM_UNAVAILABLE' });
      }
      const payload = await parseJson(response);
      if (!response.ok || !payload?.success || !payload.data?.user_id) {
        return send(res, response.status === 409 ? 409 : 401, { ok: false, code: 'OPC_SSO_EXCHANGE_FAILED' });
      }
      const session = sessionStore.create({ userId: payload.data.user_id, subject: payload.data.session_subject || String(payload.data.user_id) });
      return redirect(res, '/', {
        'set-cookie': [
          cookie(SESSION_COOKIE, session.token, { maxAge: COOKIE_MAX_AGE }),
          cookie(STATE_COOKIE, '', { maxAge: 0, clear: true }),
        ],
      });
    }

    if (req.method === 'GET' && url.pathname === '/api/session') {
      const enabled = await checkEnabled();
      if (enabled === null) return send(res, 503, { ok: false, code: 'OPC_STATUS_UNAVAILABLE' });
      if (!enabled) return send(res, 404, { ok: false, code: 'OPC_DISABLED' });
      const session = sessionStore.read(cookies[SESSION_COOKIE]);
      if (!session) return send(res, 401, { ok: false, code: 'OPC_LOGIN_REQUIRED' });
      return send(res, 200, { ok: true, data: { user_id: session.userId, subject: session.subject, expires_at: session.expiresAt } });
    }

    if (req.method === 'POST' && url.pathname === '/api/logout') {
      sessionStore.revoke(cookies[SESSION_COOKIE]);
      return send(res, 200, { ok: true }, { 'set-cookie': cookie(SESSION_COOKIE, '', { maxAge: 0, clear: true }) });
    }

    return send(res, 404, { ok: false, code: 'NOT_FOUND' });
  });
  return server;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number(process.env.PORT || 8890);
  const server = createServer({ port });
  server.listen(port, '0.0.0.0', () => {
    console.log(`OPC Service listening on port ${port}`);
  });
}

export { createServer };
