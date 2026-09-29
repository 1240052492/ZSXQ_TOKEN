export class NewApiClientError extends Error {
  constructor(message, { status = 0, code = 'NEW_API_CLIENT_ERROR' } = {}) {
    super(message);
    this.name = 'NewApiClientError';
    this.status = status;
    this.code = code;
  }
}

export class NewApiClient {
  #baseUrl;
  #serviceToken;
  #fetch;
  #timeoutMs;

  constructor({ baseUrl, serviceToken, fetchImpl = globalThis.fetch, timeoutMs = 10_000 }) {
    if (!baseUrl || !serviceToken || typeof fetchImpl !== 'function') {
      throw new Error('baseUrl, serviceToken and fetchImpl are required');
    }
    this.#baseUrl = baseUrl.replace(/\/$/, '');
    this.#serviceToken = serviceToken;
    this.#fetch = fetchImpl;
    this.#timeoutMs = timeoutMs;
  }

  async exchangeCanvasCode({ code, state }) {
    if (!code || !state) throw new NewApiClientError('code and state are required', { code: 'INVALID_REQUEST' });
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.#timeoutMs);
    try {
      const response = await this.#fetch(`${this.#baseUrl}/internal/v1/sso/exchange`, {
        method: 'POST',
        signal: controller.signal,
        headers: {
          authorization: `Bearer ${this.#serviceToken}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({ code, audience: 'canvas', state }),
      });
      let payload = null;
      try { payload = await response.json(); } catch { /* normalize non-JSON errors below */ }
      if (!response.ok) {
        throw new NewApiClientError(payload?.error?.message || 'New API SSO exchange failed', {
          status: response.status,
          code: payload?.error?.code || 'SSO_EXCHANGE_FAILED',
        });
      }
      if (!payload?.user_id || !payload?.session_subject) {
        throw new NewApiClientError('New API SSO response is missing user_id/session_subject', {
          status: response.status,
          code: 'INVALID_SSO_RESPONSE',
        });
      }
      return { userId: payload.user_id, sessionSubject: payload.session_subject };
    } catch (error) {
      if (error instanceof NewApiClientError) throw error;
      throw new NewApiClientError('New API SSO exchange unavailable', { code: 'UPSTREAM_UNAVAILABLE' });
    } finally {
      clearTimeout(timer);
    }
  }
}
