import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from '../src/server.js';

test('gateway contract requires New API configuration before login redirect', async () => {
  const server = createServer({ port: 0, newApiBaseUrl: '' });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  const response = await fetch(`http://127.0.0.1:${address.port}/canvas/login`);
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, 'NEW_API_NOT_CONFIGURED');
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
});

test('gateway sends the local canvas entry to the running canvas app', async () => {
  const server = createServer({ port: 0, canvasAppUrl: 'http://127.0.0.1:3013/' });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  const response = await fetch(`http://127.0.0.1:${address.port}/canvas`, { redirect: 'manual' });
  assert.equal(response.status, 303);
  assert.equal(response.headers.get('location'), 'http://127.0.0.1:3013/');
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
});
