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

  async listCanvasModels(capability) {
    if (!capability) throw new NewApiClientError('capability is required', { code: 'INVALID_REQUEST' });
    const payload = await this.#request(`/internal/v1/models/catalog?capability=${encodeURIComponent(capability)}`, { method: 'GET' });
    if (!Array.isArray(payload?.items)) throw new NewApiClientError('New API model catalog is invalid', { code: 'INVALID_CATALOG_RESPONSE' });
    return payload.items;
  }

  async quoteTask(request) {
    return this.#request('/internal/v1/quotes', { body: request, required: ['quote_id', 'price_version', 'estimated_quota'] });
  }

  async reserveQuota(request, idempotencyKey) {
    return this.#request('/internal/v1/reservations', { body: request, idempotencyKey, required: ['reservation_id', 'reserved_quota', 'status'] });
  }

  async invokeModel(request, idempotencyKey) {
    return this.#request('/internal/v1/model-proxy/invoke', { body: request, idempotencyKey, required: ['request_id', 'task_id', 'status'] });
  }

  async settleUsage(request, idempotencyKey) {
    return this.#request('/internal/v1/settlements', { body: request, idempotencyKey, required: ['reservation_id', 'status', 'charged_usage', 'refunded_usage'] });
  }

  async #request(path, { method = 'POST', body, idempotencyKey, required = [] } = {}) {
    if (idempotencyKey && idempotencyKey.length < 16) throw new NewApiClientError('idempotency key is too short', { code: 'INVALID_REQUEST' });
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.#timeoutMs);
    try {
      const response = await this.#fetch(`${this.#baseUrl}${path}`, {
        method,
        signal: controller.signal,
        headers: {
          authorization: `Bearer ${this.#serviceToken}`,
          ...(body ? { 'content-type': 'application/json' } : {}),
          ...(idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      let payload = null;
      try { payload = await response.json(); } catch { /* normalized below */ }
      if (!response.ok) {
        throw new NewApiClientError(payload?.error?.message || 'New API request failed', {
          status: response.status,
          code: payload?.error?.code || 'NEW_API_REQUEST_FAILED',
        });
      }
      if (required.some((field) => payload?.[field] === undefined || payload?.[field] === null)) {
        throw new NewApiClientError('New API response is missing required fields', { status: response.status, code: 'INVALID_UPSTREAM_RESPONSE' });
      }
      return payload;
    } catch (error) {
      if (error instanceof NewApiClientError) throw error;
      throw new NewApiClientError('New API request unavailable', { code: 'UPSTREAM_UNAVAILABLE' });
    } finally {
      clearTimeout(timer);
    }
  }
}
