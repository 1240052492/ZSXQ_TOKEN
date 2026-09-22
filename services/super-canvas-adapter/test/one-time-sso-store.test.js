import test from 'node:test';
import assert from 'node:assert/strict';
import { OneTimeSsoStore } from '../src/one-time-sso-store.js';

test('exchanges a canvas code once and returns the platform user', () => {
  const store = new OneTimeSsoStore();
  const issued = store.issue({ state: 'state-1234567890', userId: 'user-1', now: 1000 });
  assert.equal(store.exchange({ code: issued.code, state: 'state-1234567890', now: 1001 }).userId, 'user-1');
  assert.throws(() => store.exchange({ code: issued.code, state: 'state-1234567890', now: 1002 }), /expired|used/);
});

test('rejects state and audience mismatches without consuming a valid code', () => {
  const store = new OneTimeSsoStore();
  const issued = store.issue({ state: 'state-1234567890', userId: 'user-2', now: 1000 });
  assert.throws(() => store.exchange({ code: issued.code, audience: 'other', state: 'state-1234567890', now: 1001 }), /mismatch/);
  assert.throws(() => store.exchange({ code: issued.code, state: 'wrong-state', now: 1001 }), /mismatch/);
  assert.equal(store.exchange({ code: issued.code, state: 'state-1234567890', now: 1001 }).userId, 'user-2');
});

test('rejects expired codes', () => {
  const store = new OneTimeSsoStore();
  const issued = store.issue({ state: 'state-1234567890', userId: 'user-3', ttlMs: 10, now: 1000 });
  assert.throws(() => store.exchange({ code: issued.code, state: 'state-1234567890', now: issued.expiresAt }), /expired|used/);
});
