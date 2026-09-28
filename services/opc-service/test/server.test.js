import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';

import { createServer } from '../src/server.js';

function request(server, path, options = {}) {
  const address = server.address();
  return new Promise((resolve, reject) => {
    const req = http.request({ hostname: '127.0.0.1', port: address.port, path, ...options }, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
    });
    req.on('error', reject);
    req.end(options.body);
  });
}

test('OPC health reports missing SSO configuration without exposing secrets', async () => {
  const server = createServer({ port: 0 });
  await new Promise((resolve) => server.listen(0, resolve));
  try {
    const result = await request(server, '/health');
    assert.equal(result.status, 200);
    assert.deepEqual(JSON.parse(result.body), { ok: true, service: 'opc-service', configured: false });
  } finally {
    server.close();
  }
});

test('OPC start creates state cookie and redirects to New API', async () => {
  const server = createServer({
    port: 0,
    newApiBaseUrl: 'https://token.example.com',
    publicUrl: 'https://opc.example.com',
    internalToken: 'test-token',
    opcEnabledCheck: async () => true,
  });
  await new Promise((resolve) => server.listen(0, resolve));
  try {
    const result = await request(server, '/sso/start');
    assert.equal(result.status, 303);
    assert.match(result.headers.location, /^https:\/\/token\.example\.com\/api\/user\/auth\/opc\/authorize\?/);
    assert.match(result.headers['set-cookie'][0], /^opc_sso_state=/);
  } finally {
    server.close();
  }
});

test('OPC entry rejects access when New API disables the module', async () => {
  const server = createServer({
    port: 0,
    newApiBaseUrl: 'https://token.example.com',
    publicUrl: 'https://opc.example.com',
    internalToken: 'test-token',
    opcEnabledCheck: async () => false,
  });
  await new Promise((resolve) => server.listen(0, resolve));
  try {
    const result = await request(server, '/sso/start');
    assert.equal(result.status, 404);
    assert.deepEqual(JSON.parse(result.body), { ok: false, code: 'OPC_DISABLED' });
  } finally {
    server.close();
  }
});

test('OPC callback exchanges one code into a local session', async () => {
  const server = createServer({
    port: 0,
    newApiBaseUrl: 'https://token.example.com',
    publicUrl: 'https://opc.example.com',
    internalToken: 'test-token',
    opcEnabledCheck: async () => true,
    fetchImpl: async () => ({
      ok: true,
      status: 200,
      json: async () => ({ success: true, data: { user_id: 42, session_subject: 'session-42' } }),
    }),
  });
  await new Promise((resolve) => server.listen(0, resolve));
  try {
    const start = await request(server, '/sso/start');
    const stateCookie = start.headers['set-cookie'][0].split(';', 1)[0];
    const state = decodeURIComponent(stateCookie.split('=', 2)[1]);
    const callback = await request(server, `/sso/callback?code=one-time-code&state=${encodeURIComponent(state)}`, {
      headers: { cookie: stateCookie },
    });
    assert.equal(callback.status, 303);
    const sessionCookie = callback.headers['set-cookie'][0].split(';', 1)[0];
    const session = await request(server, '/api/session', { headers: { cookie: sessionCookie } });
    assert.equal(session.status, 200);
    assert.deepEqual(JSON.parse(session.body).data.user_id, 42);
  } finally {
    server.close();
  }
});
