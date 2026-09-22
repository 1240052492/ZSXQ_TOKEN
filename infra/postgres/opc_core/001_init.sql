BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS service_registrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_name text NOT NULL UNIQUE,
  audience text NOT NULL,
  status text NOT NULL CHECK (status IN ('active', 'disabled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS business_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key text NOT NULL UNIQUE,
  source_service text NOT NULL,
  event_type text NOT NULL,
  subject_id uuid,
  payload jsonb NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS policy_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_type text NOT NULL,
  version text NOT NULL,
  status text NOT NULL CHECK (status IN ('draft', 'published', 'retired')),
  definition jsonb NOT NULL,
  published_at timestamptz,
  UNIQUE (policy_type, version)
);

CREATE TABLE IF NOT EXISTS cross_service_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid,
  task_id uuid,
  user_id uuid,
  source_service text NOT NULL,
  event_type text NOT NULL,
  outcome text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_business_events_source_type
  ON business_events (source_service, event_type, received_at);
CREATE INDEX IF NOT EXISTS idx_audit_task_created
  ON cross_service_audit_events (task_id, created_at);

COMMIT;
