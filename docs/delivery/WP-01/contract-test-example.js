// Contract Testing Examples for New API Internal Services
// Uses Pact framework for consumer-driven contract testing

const { PactV3, MatchersV3 } = require('@pact-foundation/pact');
const { like, string, integer, regex, uuid } = MatchersV3;

// ============================================================================
// Consumer: super-canvas-adapter
// Provider: new-api-internal
// ============================================================================

describe('Canvas → New API Contract Tests', () => {
  const provider = new PactV3({
    consumer: 'super-canvas-adapter',
    provider: 'new-api-internal',
    port: 3100,
  });

  // --------------------------------------------------------------------------
  // SSO Exchange Contract
  // --------------------------------------------------------------------------
  describe('SSO Authorization Code Exchange', () => {
    it('successfully exchanges valid code', async () => {
      await provider
        .given('user 12345 exists with active status')
        .given('valid canvas auth code exists')
        .uponReceiving('request to exchange canvas auth code')
        .withRequest({
          method: 'POST',
          path: '/internal/v1/sso/exchange',
          headers: {
            'Authorization': like('Bearer svc_token_abc123'),
            'X-Service-Name': 'super-canvas-adapter',
            'X-Request-ID': uuid(),
            'Content-Type': 'application/json',
          },
          body: {
            code: string('auth_abc123xyz'),
            audience: 'canvas',
            state: string('csrf_state_xyz789'),
          },
        })
        .willRespondWith({
          status: 200,
          headers: { 'Content-Type': 'application/json' },
          body: {
            user_id: integer(12345),
            session_subject: string('sess_a1b2c3d4'),
            user_status: regex('active', /^(active|suspended|disabled)$/),
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        const result = await client.exchangeCanvasCode({
          code: 'auth_abc123xyz',
          state: 'csrf_state_xyz789',
        });
        expect(result.userId).toBe(12345);
        expect(result.sessionSubject).toBe('sess_a1b2c3d4');
      });
    });

    it('rejects expired authorization code', async () => {
      await provider
        .given('expired canvas auth code exists')
        .uponReceiving('request with expired auth code')
        .withRequest({
          method: 'POST',
          path: '/internal/v1/sso/exchange',
          body: {
            code: 'expired_code',
            audience: 'canvas',
            state: string('state_xyz'),
          },
        })
        .willRespondWith({
          status: 401,
          headers: { 'Content-Type': 'application/json' },
          body: {
            error: {
              code: 'SSO_CODE_INVALID',
              message: string('Authorization code expired or already used'),
            },
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        await expect(
          client.exchangeCanvasCode({ code: 'expired_code', state: 'state_xyz' })
        ).rejects.toThrow(/expired/i);
      });
    });

    it('rejects when user is suspended', async () => {
      await provider
        .given('user 99999 is suspended')
        .given('valid auth code for suspended user')
        .uponReceiving('exchange request for suspended user')
        .withRequest({
          method: 'POST',
          path: '/internal/v1/sso/exchange',
          body: {
            code: 'code_for_suspended_user',
            audience: 'canvas',
            state: string('state'),
          },
        })
        .willRespondWith({
          status: 403,
          body: {
            error: {
              code: 'USER_SUSPENDED',
              message: string('User account is suspended'),
            },
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        await expect(
          client.exchangeCanvasCode({ code: 'code_for_suspended_user', state: 'state' })
        ).rejects.toThrow(/suspended/i);
      });
    });
  });

  // --------------------------------------------------------------------------
  // Model Catalog Contract
  // --------------------------------------------------------------------------
  describe('Model Catalog Query', () => {
    it('returns available text models', async () => {
      await provider
        .given('user 12345 has access to text models')
        .uponReceiving('request for text model catalog')
        .withRequest({
          method: 'GET',
          path: '/internal/v1/models/catalog',
          query: {
            capability: 'text',
            user_id: '12345',
          },
          headers: {
            'Authorization': like('Bearer svc_token'),
            'X-Service-Name': 'super-canvas-adapter',
            'X-Request-ID': uuid(),
          },
        })
        .willRespondWith({
          status: 200,
          headers: { 'Content-Type': 'application/json' },
          body: {
            items: like([
              {
                id: string('gpt-4-turbo'),
                name: string('GPT-4 Turbo'),
                capabilities: like(['text']),
                price_per_1k_tokens: string('0.03'),
                price_version: string('2024-03'),
                provider_label: string('OpenAI'),
                parameter_profiles: like(['default', 'creative']),
              },
            ]),
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        const models = await client.listCanvasModels('text');
        expect(models.length).toBeGreaterThan(0);
        expect(models[0]).toHaveProperty('id');
        expect(models[0]).toHaveProperty('price_per_1k_tokens');
      });
    });

    it('returns empty array when no models available', async () => {
      await provider
        .given('user 77777 has no model access')
        .uponReceiving('catalog request from user with no access')
        .withRequest({
          method: 'GET',
          path: '/internal/v1/models/catalog',
          query: { capability: 'text', user_id: '77777' },
        })
        .willRespondWith({
          status: 200,
          body: { items: [] },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        const models = await client.listCanvasModels('text');
        expect(models).toEqual([]);
      });
    });
  });

  // --------------------------------------------------------------------------
  // Wallet Balance Contract
  // --------------------------------------------------------------------------
  describe('Wallet Balance Query', () => {
    it('returns user balance and reserved amount', async () => {
      await provider
        .given('user 12345 has balance 100.00 CNY with 5.50 reserved')
        .uponReceiving('balance query request')
        .withRequest({
          method: 'GET',
          path: '/internal/v1/wallet/balance',
          query: { user_id: '12345' },
          headers: {
            'Authorization': like('Bearer svc_token'),
            'X-Service-Name': 'super-canvas-adapter',
            'X-Request-ID': uuid(),
          },
        })
        .willRespondWith({
          status: 200,
          body: {
            balance: string('94.50'),
            currency: 'CNY',
            reserved: string('5.50'),
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        const balance = await client.getWalletBalance(12345);
        expect(balance.balance).toBe('94.50');
        expect(balance.currency).toBe('CNY');
        expect(balance.reserved).toBe('5.50');
      });
    });

    it('returns 404 for non-existent user', async () => {
      await provider
        .given('user 88888 does not exist')
        .uponReceiving('balance query for non-existent user')
        .withRequest({
          method: 'GET',
          path: '/internal/v1/wallet/balance',
          query: { user_id: '88888' },
        })
        .willRespondWith({
          status: 404,
          body: {
            error: {
              code: 'USER_NOT_FOUND',
              message: string('User not found'),
            },
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        await expect(client.getWalletBalance(88888)).rejects.toThrow(/not found/i);
      });
    });
  });

  // --------------------------------------------------------------------------
  // Quota Reservation Contract
  // --------------------------------------------------------------------------
  describe('Quota Reservation', () => {
    it('successfully reserves quota with sufficient balance', async () => {
      await provider
        .given('user 12345 has sufficient balance')
        .given('model gpt-4-turbo exists and is enabled')
        .uponReceiving('quota reservation request')
        .withRequest({
          method: 'POST',
          path: '/internal/v1/reservations',
          headers: {
            'Authorization': like('Bearer svc_token'),
            'X-Service-Name': 'super-canvas-adapter',
            'X-Request-ID': uuid(),
            'Idempotency-Key': like('idem_key_123'),
            'Content-Type': 'application/json',
          },
          body: {
            user_id: integer(12345),
            task_id: string('canvas_task_abc123'),
            model_id: 'gpt-4-turbo',
            estimated_tokens: integer(2000),
            source: 'canvas',
          },
        })
        .willRespondWith({
          status: 200,
          body: {
            reservation_id: string('rsv_def456'),
            reserved_quota: string('0.06'),
            status: 'reserved',
            expires_at: regex(
              '2024-03-15T10:30:00Z',
              /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/
            ),
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        const reservation = await client.reserveQuota(
          {
            user_id: 12345,
            task_id: 'canvas_task_abc123',
            model_id: 'gpt-4-turbo',
            estimated_tokens: 2000,
            source: 'canvas',
          },
          'idem_key_123'
        );
        expect(reservation.reservation_id).toBe('rsv_def456');
        expect(reservation.status).toBe('reserved');
      });
    });

    it('rejects reservation when balance insufficient', async () => {
      await provider
        .given('user 12345 has insufficient balance')
        .uponReceiving('reservation with insufficient balance')
        .withRequest({
          method: 'POST',
          path: '/internal/v1/reservations',
          body: {
            user_id: integer(12345),
            task_id: string('task_xyz'),
            model_id: 'gpt-4-turbo',
            estimated_tokens: integer(100000),
            source: 'canvas',
          },
        })
        .willRespondWith({
          status: 409,
          body: {
            error: {
              code: 'INSUFFICIENT_BALANCE',
              message: string('User balance insufficient for reservation'),
            },
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        await expect(
          client.reserveQuota({
            user_id: 12345,
            task_id: 'task_xyz',
            model_id: 'gpt-4-turbo',
            estimated_tokens: 100000,
            source: 'canvas',
          })
        ).rejects.toThrow(/insufficient/i);
      });
    });

    it('returns same result for duplicate idempotency key', async () => {
      await provider
        .given('reservation with idempotency key idem_duplicate already exists')
        .uponReceiving('duplicate reservation request')
        .withRequest({
          method: 'POST',
          path: '/internal/v1/reservations',
          headers: {
            'Idempotency-Key': 'idem_duplicate',
          },
          body: {
            user_id: integer(12345),
            task_id: string('task_dup'),
            model_id: 'gpt-4-turbo',
            estimated_tokens: integer(1000),
            source: 'canvas',
          },
        })
        .willRespondWith({
          status: 200,
          body: {
            reservation_id: 'rsv_original',
            reserved_quota: string('0.03'),
            status: 'reserved',
            expires_at: string('2024-03-15T10:15:00Z'),
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        const result = await client.reserveQuota(
          {
            user_id: 12345,
            task_id: 'task_dup',
            model_id: 'gpt-4-turbo',
            estimated_tokens: 1000,
            source: 'canvas',
          },
          'idem_duplicate'
        );
        expect(result.reservation_id).toBe('rsv_original');
      });
    });
  });

  // --------------------------------------------------------------------------
  // Model Invocation Contract
  // --------------------------------------------------------------------------
  describe('Model Proxy Invocation', () => {
    it('successfully invokes model and returns result', async () => {
      await provider
        .given('reservation rsv_valid123 exists and is active')
        .uponReceiving('model invocation request')
        .withRequest({
          method: 'POST',
          path: '/internal/v1/model-proxy/invoke',
          headers: {
            'Idempotency-Key': like('invoke_idem_123'),
          },
          body: {
            reservation_id: 'rsv_valid123',
            user_id: integer(12345),
            task_id: string('canvas_task_abc'),
            model_id: 'gpt-4-turbo',
            parameters: like({
              messages: [{ role: 'user', content: 'Hello' }],
              temperature: 0.7,
            }),
            source: 'canvas',
          },
        })
        .willRespondWith({
          status: 200,
          body: {
            request_id: string('req_ghi789'),
            task_id: 'canvas_task_abc',
            status: 'succeeded',
            result: like({
              content: string('Hello! How can I help?'),
              usage: {
                prompt_tokens: integer(10),
                completion_tokens: integer(8),
                total_tokens: integer(18),
              },
            }),
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        const result = await client.invokeModel(
          {
            reservation_id: 'rsv_valid123',
            user_id: 12345,
            task_id: 'canvas_task_abc',
            model_id: 'gpt-4-turbo',
            parameters: {
              messages: [{ role: 'user', content: 'Hello' }],
              temperature: 0.7,
            },
            source: 'canvas',
          },
          'invoke_idem_123'
        );
        expect(result.status).toBe('succeeded');
        expect(result.result).toHaveProperty('usage');
      });
    });

    it('rejects invocation with expired reservation', async () => {
      await provider
        .given('reservation rsv_expired has expired')
        .uponReceiving('invoke with expired reservation')
        .withRequest({
          method: 'POST',
          path: '/internal/v1/model-proxy/invoke',
          body: {
            reservation_id: 'rsv_expired',
            user_id: integer(12345),
            task_id: string('task'),
            model_id: 'gpt-4-turbo',
            parameters: like({}),
            source: 'canvas',
          },
        })
        .willRespondWith({
          status: 404,
          body: {
            error: {
              code: 'RESERVATION_EXPIRED',
              message: string('Reservation not found or expired'),
            },
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        await expect(
          client.invokeModel({
            reservation_id: 'rsv_expired',
            user_id: 12345,
            task_id: 'task',
            model_id: 'gpt-4-turbo',
            parameters: {},
            source: 'canvas',
          })
        ).rejects.toThrow(/expired/i);
      });
    });
  });

  // --------------------------------------------------------------------------
  // Settlement Contract
  // --------------------------------------------------------------------------
  describe('Usage Settlement', () => {
    it('settles usage and refunds difference', async () => {
      await provider
        .given('reservation rsv_settle123 exists with 0.06 reserved')
        .uponReceiving('settlement request')
        .withRequest({
          method: 'POST',
          path: '/internal/v1/settlements',
          headers: {
            'Idempotency-Key': like('settle_idem_123'),
          },
          body: {
            reservation_id: 'rsv_settle123',
            actual_tokens: integer(18),
            actual_usage: string('0.00054'),
          },
        })
        .willRespondWith({
          status: 200,
          body: {
            reservation_id: 'rsv_settle123',
            status: 'settled',
            charged_usage: string('0.00054'),
            refunded_usage: string('0.05946'),
            transaction_id: string('txn_jkl012'),
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        const result = await client.settleUsage(
          {
            reservation_id: 'rsv_settle123',
            actual_tokens: 18,
            actual_usage: '0.00054',
          },
          'settle_idem_123'
        );
        expect(result.status).toBe('settled');
        expect(result.refunded_usage).toBe('0.05946');
      });
    });

    it('returns same result for duplicate settlement', async () => {
      await provider
        .given('settlement for rsv_already_settled already completed')
        .uponReceiving('duplicate settlement request')
        .withRequest({
          method: 'POST',
          path: '/internal/v1/settlements',
          headers: {
            'Idempotency-Key': 'settle_dup_key',
          },
          body: {
            reservation_id: 'rsv_already_settled',
            actual_tokens: integer(20),
            actual_usage: string('0.0006'),
          },
        })
        .willRespondWith({
          status: 200,
          body: {
            reservation_id: 'rsv_already_settled',
            status: 'settled',
            charged_usage: string('0.0006'),
            refunded_usage: string('0.0'),
            transaction_id: 'txn_original',
          },
        });

      await provider.executeTest(async (mockServer) => {
        const client = createClient(mockServer.url);
        const result = await client.settleUsage(
          {
            reservation_id: 'rsv_already_settled',
            actual_tokens: 20,
            actual_usage: '0.0006',
          },
          'settle_dup_key'
        );
        expect(result.transaction_id).toBe('txn_original');
      });
    });
  });
});

// ============================================================================
// Helper Functions
// ============================================================================

function createClient(baseUrl) {
  // Mock client factory - replace with actual NewApiClient
  return {
    exchangeCanvasCode: async ({ code, state }) => {
      const res = await fetch(`${baseUrl}/internal/v1/sso/exchange`, {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer svc_token_abc123',
          'X-Service-Name': 'super-canvas-adapter',
          'X-Request-ID': crypto.randomUUID(),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ code, audience: 'canvas', state }),
      });
      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      return { userId: data.user_id, sessionSubject: data.session_subject };
    },
    // Additional methods follow similar pattern...
  };
}
