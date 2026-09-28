import test from 'node:test';
import assert from 'node:assert/strict';
import { CanvasTaskOrchestrator, MemoryTaskStore } from '../src/canvas-task-orchestrator.js';

function client({ invokeError = null } = {}) {
  const calls = [];
  return {
    calls,
    async listCanvasModels(capability) {
      calls.push(['catalog', capability]);
      return [{ platform_model_id: 'image-model', alias: 'image-standard', protocol_adapter: 'image-v1' }];
    },
    async quoteTask(body) {
      calls.push(['quote', body]);
      return { quote_id: 'quote-1', price_version: 'price-v1', estimated_quota: 100 };
    },
    async reserveQuota(body, idempotencyKey) {
      calls.push(['reserve', body, idempotencyKey]);
      return { reservation_id: 'reservation-1', reserved_quota: 100, status: 'reserved' };
    },
    async invokeModel(body, idempotencyKey) {
      calls.push(['invoke', body, idempotencyKey]);
      if (invokeError) throw invokeError;
      return { request_id: 'request-1', task_id: body.task_id, status: 'accepted' };
    },
    async settleUsage(body, idempotencyKey) {
      calls.push(['settle', body, idempotencyKey]);
      return { reservation_id: body.reservation_id, status: body.outcome === 'success' ? 'settled' : 'refunded', charged_usage: body.outcome === 'success' ? body.actual_usage : 0, refunded_usage: body.outcome === 'success' ? 100 - body.actual_usage : 100 };
    },
  };
}

test('creates a task from an eligible catalog model and settles a successful task', async () => {
  const api = client();
  const store = new MemoryTaskStore();
  const orchestrator = new CanvasTaskOrchestrator({ newApiClient: api, taskStore: store });
  const task = await orchestrator.create({ taskId: 'task-1', userId: 'user-1', capability: 'image', platformModelId: 'image-model', alias: 'image-standard', parameters: { size: '1024x1024' }, input: { prompt: 'safe prompt' } });
  assert.equal(task.status, 'queued');
  assert.equal(task.modelSnapshot.priceVersion, 'price-v1');
  assert.deepEqual(api.calls.map(([name]) => name), ['catalog', 'quote', 'reserve', 'invoke']);
  const finalized = await orchestrator.finalize({ taskId: 'task-1', outcome: 'success', actualUsage: 60 });
  assert.equal(finalized.status, 'succeeded');
  assert.equal(finalized.settlement.charged_usage, 60);
  assert.equal(finalized.settlement.refunded_usage, 40);
  const repeated = await orchestrator.finalize({ taskId: 'task-1', outcome: 'success', actualUsage: 60 });
  assert.deepEqual(repeated.settlement, finalized.settlement);
  assert.equal(api.calls.filter(([name]) => name === 'settle').length, 1);
});

test('rejects usage above the reserved quota before settlement', async () => {
  const api = client();
  const orchestrator = new CanvasTaskOrchestrator({ newApiClient: api, taskStore: new MemoryTaskStore() });
  await orchestrator.create({ taskId: 'task-limit', userId: 'user-1', capability: 'image', platformModelId: 'image-model', alias: 'image-standard', parameters: {}, input: {} });
  await assert.rejects(() => orchestrator.finalize({ taskId: 'task-limit', outcome: 'success', actualUsage: 101 }), /exceeds reserved quota/);
  assert.equal(api.calls.filter(([name]) => name === 'settle').length, 0);
});

test('rejects a model not in the canvas-filtered catalog before quote or reserve', async () => {
  const api = client();
  const orchestrator = new CanvasTaskOrchestrator({ newApiClient: api, taskStore: new MemoryTaskStore() });
  await assert.rejects(() => orchestrator.create({ userId: 'user-1', capability: 'image', platformModelId: 'other-model', alias: 'different', parameters: {}, input: {} }), /unavailable/);
  assert.deepEqual(api.calls.map(([name]) => name), ['catalog']);
});

test('refunds reservation when the controlled model proxy fails', async () => {
  const failure = Object.assign(new Error('upstream failed'), { code: 'UPSTREAM_UNAVAILABLE' });
  const api = client({ invokeError: failure });
  const store = new MemoryTaskStore();
  const orchestrator = new CanvasTaskOrchestrator({ newApiClient: api, taskStore: store });
  await assert.rejects(() => orchestrator.create({ taskId: 'task-fail', userId: 'user-1', capability: 'image', platformModelId: 'image-model', alias: 'image-standard', parameters: {}, input: {} }), /upstream failed/);
  const settlement = api.calls.find(([name]) => name === 'settle');
  assert.equal(settlement[1].outcome, 'failed');
  assert.equal(settlement[1].actual_usage, 0);
  assert.equal(store.read('task-fail').status, 'refunded');
});
