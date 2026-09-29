import { randomBytes, timingSafeEqual } from 'node:crypto';

const STATE_COOKIE = 'canvas_sso_state';
const SESSION_COOKIE = 'canvas_session';

function equal(left, right) {
  const a = Buffer.from(left || '');
  const b = Buffer.from(right || '');
  return a.length === b.length && timingSafeEqual(a, b);
}

function parseCookies(header = '') {
  return Object.fromEntries(header.split(';').map((entry) => entry.trim().split('=').map(decodeURIComponent)).filter(([key]) => key));
}

function cookie(name, value, { maxAge = 0, httpOnly = true } = {}) {
  const flags = [`${name}=${encodeURIComponent(value)}`, 'Path=/', 'SameSite=Lax', `Max-Age=${maxAge}`];
  if (httpOnly) flags.push('HttpOnly');
  return flags.join('; ');
}

export function createSsoCallbackHandler({ newApiClient, sessionStore, redirectPath = '/' }) {
  if (!newApiClient || !sessionStore) throw new Error('newApiClient and sessionStore are required');
  return async (req, res) => {
    const { code, state } = req.query || {};
    const cookies = parseCookies(req.headers?.cookie);
    if (!code || !state || !equal(cookies[STATE_COOKIE], state)) {
      res.status(400).json({ error: { code: 'SSO_STATE_INVALID', message: 'Invalid SSO callback state' } });
      return;
    }
    try {
      const subject = await newApiClient.exchangeCanvasCode({ code, state });
      const session = sessionStore.create(subject);
      res.setHeader('Set-Cookie', [
        cookie(STATE_COOKIE, '', { maxAge: 0 }),
        cookie(SESSION_COOKIE, session.token, { maxAge: Math.floor((session.expiresAt - Date.now()) / 1000) }),
      ]);
      res.redirect(303, redirectPath);
    } catch (error) {
      res.status(error.status === 401 ? 401 : 502).json({ error: { code: error.code || 'SSO_EXCHANGE_FAILED', message: 'Canvas sign-in failed' } });
    }
  };
}

export function createSsoStartHandler({ newApiAuthorizeUrl, redirectUri }) {
  if (!newApiAuthorizeUrl || !redirectUri) throw new Error('newApiAuthorizeUrl and redirectUri are required');
  return (req, res) => {
    const state = randomBytes(24).toString('base64url');
    res.setHeader('Set-Cookie', cookie(STATE_COOKIE, state, { maxAge: 300 }));
    const url = new URL(newApiAuthorizeUrl);
    url.searchParams.set('audience', 'canvas');
    url.searchParams.set('state', state);
    url.searchParams.set('redirect_uri', redirectUri);
    res.redirect(303, url.toString());
  };
}

export const ssoCookies = { STATE_COOKIE, SESSION_COOKIE, parseCookies };
