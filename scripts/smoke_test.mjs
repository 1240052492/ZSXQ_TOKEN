import assert from 'node:assert/strict';
import { CanvasTaskOrchestrator, MemoryTaskStore } from '../services/super-canvas-adapter/src/canvas-task-orchestrator.js';
import { OneTimeSsoStore } from '../services/super-canvas-adapter/src/one-time-sso-store.js';
import { CanvasSessionStore } from '../services/super-canvas-adapter/src/canvas-session-store.js';
import { createSsoCallbackHandler, createSsoStartHandler, ssoCookies } from '../services/super-canvas-adapter/src/sso-callback-handler.js';

const checks = [];
const check = (name, fn) => { fn(); checks.push(name); };

// Simulate the browser click on “Sign in”, followed by the provider callback.
const codeStore = new OneTimeSsoStore();
const sessionStore = new CanvasSessionStore();
const subject = { userId: 'smoke-user', sessionSubject: 'smoke-subject' };
const api = {
  async exchangeCanvasCode({ code, state }) {
    const result = codeStore.exchange({ code, state });
    return { userId: result.userId, sessionSubject: subject.sessionSubject };
  },
};
let startResponse = {};
const start = createSsoStartHandler({ newApiAuthorizeUrl: 'https://new-api.test/sso/authorize', redirectUri: 'https://canvas.test/sso/callback' });
start({}, { setHeader(name, value) { startResponse[name] = value; }, redirect(status, url) { startResponse.status = status; startResponse.url = url; } });
check('login click redirects to provider', () => {
  assert.equal(startResponse.status, 303);
  assert.match(startResponse.url, /audience=canvas/);
});
const stateCookie = startResponse['Set-Cookie'].split(';', 1)[0];
const state = decodeURIComponent(stateCookie.split('=')[1]);
const issued = codeStore.issue({ state, userId: subject.userId });
let callbackResponse = {};
const callback = createSsoCallbackHandler({ newApiClient: api, sessionStore, redirectPath: '/studio' });
await callback(
  { query: { code: issued.code, state }, headers: { cookie: stateCookie } },
  { setHeader(name, value) { callbackResponse[name] = value; }, redirect(status, url) { callbackResponse.status = status; callbackResponse.url = url; }, status(code) { callbackResponse.statusCode = code; return { json(payload) { callbackResponse.payload = payload; } }; } },
);
check('callback creates session and opens studio', () => {
  assert.equal(callbackResponse.status, 303);
  assert.equal(callbackResponse.url, '/studio');
  const sessionToken = callbackResponse['Set-Cookie'].find((value) => value.startsWith(`${ssoCookies.SESSION_COOKIE}=`)).split(';', 1)[0].split('=')[1];
  assert.equal(sessionStore.read(sessionToken).userId, subject.userId);
});

function taskApi({ failInvoke = false } = {}) {
  const calls = [];
  return { calls,
    async listCanvasModels() { calls.push('catalog'); return [{ platform_model_id: 'image-model', alias: 'image-standard', protocol_adapter: 'image-v1' }]; },
    async quoteTask() { calls.push('quote'); return { quote_id: 'quote-smoke', price_version: 'price-v1', estimated_quota: 100 }; },
    async reserveQuota() { calls.push('reserve'); return { reservation_id: 'reservation-smoke', reserved_quota: 100, status: 'reserved' }; },
    async invokeModel() { calls.push('invoke'); if (failInvoke) throw Object.assign(new Error('upstream unavailable'), { code: 'UPSTREAM_UNAVAILABLE' }); return { request_id: 'request-smoke', task_id: 'task-smoke', status: 'accepted' }; },
    async settleUsage(body) { calls.push('settle'); return { reservation_id: body.reservation_id, status: body.outcome === 'success' ? 'settled' : 'refunded', charged_usage: body.outcome === 'success' ? body.actual_usage : 0, refunded_usage: body.outcome === 'success' ? 40 : 100 }; },
  };
}
const taskApiSuccess = taskApi();
const orchestrator = new CanvasTaskOrchestrator({ newApiClient: taskApiSuccess, taskStore: new MemoryTaskStore() });
const task = await orchestrator.create({ taskId: 'task-smoke', userId: subject.userId, capability: 'image', platformModelId: 'image-model', alias: 'image-standard', parameters: { size: '1024x1024' }, input: { prompt: 'smoke prompt' } });
check('task submission reaches queued state', () => { assert.equal(task.status, 'queued'); assert.deepEqual(taskApiSuccess.calls, ['catalog', 'quote', 'reserve', 'invoke']); });
const settled = await orchestrator.finalize({ taskId: 'task-smoke', outcome: 'success', actualUsage: 60 });
check('successful task settles and refunds unused quota', () => { assert.equal(settled.status, 'succeeded'); assert.equal(settled.settlement.refunded_usage, 40); });

const failedApi = taskApi({ failInvoke: true });
const failedStore = new MemoryTaskStore();
const failedOrchestrator = new CanvasTaskOrchestrator({ newApiClient: failedApi, taskStore: failedStore });
await assert.rejects(() => failedOrchestrator.create({ taskId: 'task-fail-smoke', userId: subject.userId, capability: 'image', platformModelId: 'image-model', alias: 'image-standard', parameters: {}, input: {} }), /upstream unavailable/);
check('proxy failure refunds reservation', () => { assert.equal(failedStore.read('task-fail-smoke').status, 'refunded'); assert.equal(failedApi.calls.at(-1), 'settle'); });

console.log(`Smoke test passed: ${checks.length} checks`);
for (const name of checks) console.log(`- ${name}`);
