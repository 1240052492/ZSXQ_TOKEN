import { createHash, randomBytes } from 'node:crypto';

function digest(value) {
  return createHash('sha256').update(value).digest('hex');
}

export class OpcSessionStore {
  #sessions = new Map();

  create({ userId, subject, ttlMs = 8 * 60 * 60 * 1000, now = Date.now() }) {
    if (!userId || !subject) throw new Error('userId and subject are required');
    const token = randomBytes(32).toString('base64url');
    this.#sessions.set(digest(token), { userId, subject, expiresAt: now + ttlMs });
    return { token, expiresAt: now + ttlMs };
  }

  read(token, { now = Date.now() } = {}) {
    if (!token) return null;
    const key = digest(token);
    const session = this.#sessions.get(key);
    if (!session || session.expiresAt <= now) {
      this.#sessions.delete(key);
      return null;
    }
    return { ...session };
  }

  revoke(token) {
    if (token) this.#sessions.delete(digest(token));
  }
}
