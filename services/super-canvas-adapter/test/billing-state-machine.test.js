import test from 'node:test';
import assert from 'node:assert/strict';
import { BillingStateMachine } from '../src/billing-state-machine.js';

function quote(machine, taskId = 'task-1') {
  return machine.quote({ taskId, userId: 'user-1', estimatedQuota: 100, modelSnapshot: { platformModelId: 'model-1', priceVersion: 'price-v1' } });
}

test('success settles actual usage and releases unused reservation', () => {
  const machine = new BillingStateMachine();
  const reservation = machine.reserve({ quoteId: quote(machine).quoteId, idempotencyKey: 'reserve-1234567890' });
  const result = machine.settle({ reservationId: reservation.reservationId, outcome: 'success', actualUsage: 60, idempotencyKey: 'settle-1234567890' });
  assert.equal(result.status, 'settled');
  assert.equal(result.chargedQuota, 60);
  assert.equal(result.refundedQuota, 40);
  assert.equal(result.priceVersion, 'price-v1');
});

test('failure, cancellation and moderation rejection return all reserved quota', () => {
  for (const outcome of ['failed', 'cancelled', 'moderation_rejected']) {
    const machine = new BillingStateMachine();
    const reservation = machine.reserve({ quoteId: quote(machine, `task-${outcome}`).quoteId, idempotencyKey: `reserve-${outcome}-123456` });
    const result = machine.settle({ reservationId: reservation.reservationId, outcome, actualUsage: 0, idempotencyKey: `settle-${outcome}-123456` });
    assert.equal(result.chargedQuota, 0);
    assert.equal(result.refundedQuota, 100);
  }
});

test('retries are idempotent and conflicting repeats are rejected', () => {
  const machine = new BillingStateMachine();
  const q = quote(machine);
  const first = machine.reserve({ quoteId: q.quoteId, idempotencyKey: 'reserve-retry-123456' });
  const second = machine.reserve({ quoteId: q.quoteId, idempotencyKey: 'reserve-retry-123456' });
  assert.equal(first.reservationId, second.reservationId);
  assert.throws(() => machine.reserve({ quoteId: quote(machine, 'task-other').quoteId, idempotencyKey: 'reserve-retry-123456' }), /payload mismatch/);
  const settled = machine.settle({ reservationId: first.reservationId, outcome: 'success', actualUsage: 20, idempotencyKey: 'settle-retry-123456' });
  assert.equal(machine.settle({ reservationId: first.reservationId, outcome: 'success', actualUsage: 20, idempotencyKey: 'settle-retry-123456' }).chargedQuota, settled.chargedQuota);
  assert.throws(() => machine.settle({ reservationId: first.reservationId, outcome: 'success', actualUsage: 21, idempotencyKey: 'settle-retry-123456' }), /payload mismatch/);
});

test('never permits settlement above the reservation or double finalization', () => {
  const machine = new BillingStateMachine();
  const reservation = machine.reserve({ quoteId: quote(machine).quoteId, idempotencyKey: 'reserve-limit-123456' });
  assert.throws(() => machine.settle({ reservationId: reservation.reservationId, outcome: 'success', actualUsage: 101, idempotencyKey: 'settle-limit-123456' }), /exceeds/);
  machine.settle({ reservationId: reservation.reservationId, outcome: 'failed', actualUsage: 0, idempotencyKey: 'settle-final-123456' });
  assert.throws(() => machine.settle({ reservationId: reservation.reservationId, outcome: 'success', actualUsage: 1, idempotencyKey: 'settle-after-final-123456' }), /already finalized/);
});
