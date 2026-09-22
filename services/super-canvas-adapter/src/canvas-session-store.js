import { createHash, randomBytes } from 'node:crypto';

function digest(value) {
  return createHash('sha256').update(value).digest('hex');
}

export class CanvasSessionStore {
  #sessions = new Map();

  create({ userId, sessionSubject, ttlMs = 8 * 60 * 60 * 1000, now = Date.now() }) {
    if (!userId || !sessionSubject) throw new Error('userId and sessionSubject are required');
    const token = randomBytes(32).toString('base64url');
    this.#sessions.set(digest(token), { userId, sessionSubject, expiresAt: now + ttlMs });
    return { token, expiresAt: now + ttlMs };
  }

  read(token, { now = Date.now() } = {}) {
    if (!token) return null;
    const record = this.#sessions.get(digest(token));
    if (!record || record.expiresAt <= now) {
      if (record) this.#sessions.delete(digest(token));
      return null;
    }
    return { userId: record.userId, sessionSubject: record.sessionSubject, expiresAt: record.expiresAt };
  }

  revoke(token) {
    if (token) this.#sessions.delete(digest(token));
  }
}
