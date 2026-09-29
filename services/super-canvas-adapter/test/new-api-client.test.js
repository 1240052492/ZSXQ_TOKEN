import test from 'node:test';
import assert from 'node:assert/strict';
import { NewApiClient, NewApiClientError } from '../src/new-api-client.js';

test('exchanges a code with canvas audience and service authorization', async () => {
  let request;
  const client = new NewApiClient({
    baseUrl: 'http://new-api.internal/',
    serviceToken: 'service-token-demo',
    fetchImpl: async (url, options) => {
      request = { url, options };
      return { ok: true, status: 200, json: async () => ({ user_id: 'u-1', session_subject: 's-1' }) };
    },
  });
  assert.deepEqual(await client.exchangeCanvasCode({ code: 'opaque-code', state: 'state-value' }), {
    userId: 'u-1', sessionSubject: 's-1',
  });
  assert.equal(request.url, 'http://new-api.internal/internal/v1/sso/exchange');
  assert.equal(request.options.headers.authorization, 'Bearer service-token-demo');
  assert.deepEqual(JSON.parse(request.options.body), { code: 'opaque-code', audience: 'canvas', state: 'state-value' });
});

test('maps upstream rejection and malformed success responses', async () => {
  const rejected = new NewApiClient({
    baseUrl: 'http://new-api.internal', serviceToken: 'token',
    fetchImpl: async () => ({ ok: false, status: 401, json: async () => ({ error: { code: 'SSO_REJECTED', message: 'rejected' } }) }),
  });
  await assert.rejects(() => rejected.exchangeCanvasCode({ code: 'c', state: 's' }), (error) => {
    assert.ok(error instanceof NewApiClientError);
    assert.equal(error.status, 401);
    assert.equal(error.code, 'SSO_REJECTED');
    return true;
  });

  const malformed = new NewApiClient({
    baseUrl: 'http://new-api.internal', serviceToken: 'token',
    fetchImpl: async () => ({ ok: true, status: 200, json: async () => ({ user_id: 'u-only' }) }),
  });
  await assert.rejects(() => malformed.exchangeCanvasCode({ code: 'c', state: 's' }), /missing user_id\/session_subject/);
});

test('does not expose a raw upstream fetch error', async () => {
  const client = new NewApiClient({
    baseUrl: 'http://new-api.internal', serviceToken: 'token',
    fetchImpl: async () => { throw new Error('socket details should not escape'); },
  });
  await assert.rejects(() => client.exchangeCanvasCode({ code: 'c', state: 's' }), (error) => {
    assert.equal(error.code, 'UPSTREAM_UNAVAILABLE');
    assert.equal(error.message, 'New API SSO exchange unavailable');
    return true;
  });
});
