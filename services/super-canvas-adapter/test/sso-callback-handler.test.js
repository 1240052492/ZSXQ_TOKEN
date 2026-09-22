import test from 'node:test';
import assert from 'node:assert/strict';
import { CanvasSessionStore } from '../src/canvas-session-store.js';
import { createSsoCallbackHandler, createSsoStartHandler, ssoCookies } from '../src/sso-callback-handler.js';

function response() {
  return {
    statusCode: 200, headers: {}, body: null, redirectUrl: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
    setHeader(name, value) { this.headers[name] = value; },
    redirect(code, url) { this.statusCode = code; this.redirectUrl = url; return this; },
  };
}

test('SSO start stores state in HttpOnly cookie and redirects to New API', () => {
  const res = response();
  createSsoStartHandler({ newApiAuthorizeUrl: 'https://token.demo/sso/authorize', redirectUri: 'https://canvas.demo/sso/callback' })({}, res);
  assert.equal(res.statusCode, 303);
  assert.match(res.headers['Set-Cookie'], /canvas_sso_state=/);
  assert.match(res.headers['Set-Cookie'], /HttpOnly/);
  const url = new URL(res.redirectUrl);
  assert.equal(url.searchParams.get('audience'), 'canvas');
  assert.equal(url.searchParams.get('redirect_uri'), 'https://canvas.demo/sso/callback');
});

test('callback validates state, creates HttpOnly canvas session, and redirects', async () => {
  const state = 'state-1234567890';
  const sessionStore = new CanvasSessionStore();
  const handler = createSsoCallbackHandler({
    newApiClient: { exchangeCanvasCode: async ({ code, state: received }) => {
      assert.equal(code, 'opaque-code'); assert.equal(received, state); return { userId: 'u-1', sessionSubject: 's-1' };
    } }, sessionStore, redirectPath: '/canvas',
  });
  const res = response();
  await handler({ query: { code: 'opaque-code', state }, headers: { cookie: `${ssoCookies.STATE_COOKIE}=${state}` } }, res);
  assert.equal(res.statusCode, 303);
  assert.equal(res.redirectUrl, '/canvas');
  const cookies = res.headers['Set-Cookie'];
  assert.equal(cookies.length, 2);
  assert.match(cookies[1], /canvas_session=/);
  assert.match(cookies[1], /HttpOnly/);
  const token = decodeURIComponent(cookies[1].match(/canvas_session=([^;]+)/)[1]);
  assert.equal(sessionStore.read(token).userId, 'u-1');
});

test('callback rejects mismatched state without exchanging the code', async () => {
  let exchanged = false;
  const handler = createSsoCallbackHandler({ newApiClient: { exchangeCanvasCode: async () => { exchanged = true; } }, sessionStore: new CanvasSessionStore() });
  const res = response();
  await handler({ query: { code: 'opaque-code', state: 'wrong' }, headers: { cookie: 'canvas_sso_state=expected' } }, res);
  assert.equal(res.statusCode, 400);
  assert.equal(res.body.error.code, 'SSO_STATE_INVALID');
  assert.equal(exchanged, false);
});
