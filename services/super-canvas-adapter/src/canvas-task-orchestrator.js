import { randomUUID } from 'node:crypto';

function key(prefix, taskId) {
  return `${prefix}:${taskId}:${randomUUID()}`;
}

/** Coordinates canvas tasks without keeping a second wallet or provider key. */
export class CanvasTaskOrchestrator {
  constructor({ newApiClient, taskStore }) {
    if (!newApiClient || !taskStore) throw new Error('newApiClient and taskStore are required');
    this.newApiClient = newApiClient;
    this.taskStore = taskStore;
  }

  async create({ taskId = randomUUID(), userId, capability, platformModelId, alias, parameters, input }) {
    const catalog = await this.newApiClient.listCanvasModels(capability);
    const model = catalog.find((item) => item.platform_model_id === platformModelId && item.alias === alias);
    if (!model) throw new Error('canvas model is unavailable for this capability');
    const quote = await this.newApiClient.quoteTask({ user_id: userId, task_id: taskId, platform_model_id: platformModelId, alias, capability, parameters });
    const reservation = await this.newApiClient.reserveQuota({ user_id: userId, task_id: taskId, platform_model_id: platformModelId, alias, capability, parameters, quote_id: quote.quote_id }, key('reserve', taskId));
    const snapshot = { platformModelId, alias, capability, priceVersion: quote.price_version, protocolAdapter: model.protocol_adapter, parameters: structuredClone(parameters) };
    const task = { taskId, userId, status: 'reserved', reservationId: reservation.reservation_id, modelSnapshot: snapshot, quote, reservation };
    this.taskStore.save(task);
    try {
      const invocation = await this.newApiClient.invokeModel({ reservation_id: reservation.reservation_id, task_id: taskId, model_snapshot: snapshot, input }, key('invoke', taskId));
      task.status = 'queued'; task.requestId = invocation.request_id; this.taskStore.save(task);
      return structuredClone(task);
    } catch (error) {
      await this.finalize({ taskId, outcome: 'failed', actualUsage: 0, failureCode: error.code || 'INVOKE_FAILED' });
      throw error;
    }
  }

  async finalize({ taskId, outcome, actualUsage, failureCode }) {
    const task = this.taskStore.read(taskId);
    if (!task) throw new Error('task not found');
    if (task.settlement) return structuredClone(task);
    if (!Number.isFinite(actualUsage) || actualUsage < 0) throw new Error('actual usage must be a non-negative number');
    if (actualUsage > task.reservation.reserved_quota) throw new Error('actual usage exceeds reserved quota');
    const settlement = await this.newApiClient.settleUsage({ reservation_id: task.reservationId, task_id: taskId, outcome, actual_usage: actualUsage, failure_code: failureCode }, `settle:${taskId}`);
    task.status = settlement.status === 'settled' ? 'succeeded' : settlement.status;
    task.settlement = settlement;
    this.taskStore.save(task);
    return structuredClone(task);
  }
}

export class MemoryTaskStore {
  #tasks = new Map();
  save(task) { this.#tasks.set(task.taskId, structuredClone(task)); }
  read(taskId) { const task = this.#tasks.get(taskId); return task ? structuredClone(task) : null; }
}
