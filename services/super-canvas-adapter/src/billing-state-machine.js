import { createHash, randomUUID } from 'node:crypto';

function digest(value) {
  return createHash('sha256').update(JSON.stringify(value)).digest('hex');
}

function conflict(message) {
  const error = new Error(message);
  error.code = 'IDEMPOTENCY_CONFLICT';
  return error;
}

/**
 * Local reference for New API billing semantics. It deliberately stores no
 * wallet balance: production calls quote/reserve/settle over NewApiClient.
 */
export class BillingStateMachine {
  #quotes = new Map();
  #reservations = new Map();
  #idempotency = new Map();

  quote({ taskId, userId, modelSnapshot, estimatedQuota }) {
    if (!taskId || !userId || !modelSnapshot?.priceVersion || !Number.isInteger(estimatedQuota) || estimatedQuota < 0) {
      throw new Error('invalid quote request');
    }
    const quote = {
      quoteId: randomUUID(), taskId, userId, modelSnapshot: structuredClone(modelSnapshot), estimatedQuota,
      priceVersion: modelSnapshot.priceVersion,
    };
    this.#quotes.set(quote.quoteId, quote);
    return structuredClone(quote);
  }

  reserve({ quoteId, idempotencyKey }) {
    const quote = this.#quotes.get(quoteId);
    if (!quote || !idempotencyKey) throw new Error('invalid reservation request');
    return this.#idem(`reserve:${idempotencyKey}`, { quoteId }, () => {
      const reservation = {
        reservationId: randomUUID(), quoteId, taskId: quote.taskId, userId: quote.userId,
        priceVersion: quote.priceVersion, reservedQuota: quote.estimatedQuota, status: 'reserved',
      };
      this.#reservations.set(reservation.reservationId, reservation);
      return reservation;
    });
  }

  settle({ reservationId, outcome, actualUsage, idempotencyKey, failureCode }) {
    const reservation = this.#reservations.get(reservationId);
    if (!reservation || !idempotencyKey || !Number.isInteger(actualUsage) || actualUsage < 0) {
      throw new Error('invalid settlement request');
    }
    if (!['success', 'failed', 'cancelled', 'moderation_rejected'].includes(outcome)) throw new Error('invalid settlement outcome');
    return this.#idem(`settle:${idempotencyKey}`, { reservationId, outcome, actualUsage, failureCode: failureCode || null }, () => {
      if (reservation.status !== 'reserved') throw conflict('reservation is already finalized');
      const success = outcome === 'success';
      if (success && actualUsage > reservation.reservedQuota) throw new Error('actual usage exceeds reserved quota');
      reservation.status = success ? 'settled' : (outcome === 'failed' ? 'refunded' : 'released');
      reservation.actualUsage = success ? actualUsage : 0;
      reservation.chargedQuota = success ? actualUsage : 0;
      reservation.refundedQuota = success ? reservation.reservedQuota - actualUsage : reservation.reservedQuota;
      reservation.failureCode = success ? null : failureCode || outcome;
      return reservation;
    });
  }

  #idem(key, payload, action) {
    const fingerprint = digest(payload);
    const prior = this.#idempotency.get(key);
    if (prior) {
      if (prior.fingerprint !== fingerprint) throw conflict('idempotency key payload mismatch');
      return structuredClone(prior.value);
    }
    const value = action();
    this.#idempotency.set(key, { fingerprint, value: structuredClone(value) });
    return structuredClone(value);
  }
}
