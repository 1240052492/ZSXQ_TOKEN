import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

function digest(value) {
  return createHash('sha256').update(value).digest('hex');
}

function safeEqual(left, right) {
  const a = Buffer.from(left);
  const b = Buffer.from(right);
  return a.length === b.length && timingSafeEqual(a, b);
}

/**
 * Canvas-side reference implementation for consuming New API SSO codes.
 * Only the hash is retained; production persistence belongs to the control
 * plane and the canvas session store, not to browser storage.
 */
export class OneTimeSsoStore {
  #codes = new Map();

  issue({ audience = 'canvas', state, userId, ttlMs = 60_000, now = Date.now() }) {
    if (audience !== 'canvas' || !state || !userId) throw new Error('invalid SSO issue request');
    const code = randomBytes(32).toString('base64url');
    this.#codes.set(digest(code), {
      audience,
      stateHash: digest(state),
      userId,
      expiresAt: now + ttlMs,
      consumed: false,
    });
    return { code, expiresAt: now + ttlMs };
  }

  exchange({ code, audience = 'canvas', state, now = Date.now() }) {
    if (!code || !state) throw new Error('invalid SSO exchange request');
    const record = this.#codes.get(digest(code));
    if (!record || record.consumed || record.expiresAt <= now) throw new Error('SSO code expired or already used');
    if (record.audience !== audience || !safeEqual(record.stateHash, digest(state))) {
      throw new Error('SSO audience or state mismatch');
    }
    record.consumed = true;
    this.#codes.delete(digest(code));
    return { userId: record.userId, audience: record.audience };
  }
}
