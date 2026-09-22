BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS platform_user_refs (
  user_id uuid PRIMARY KEY,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL CHECK (status IN ('active', 'disabled'))
);

CREATE TABLE IF NOT EXISTS canvas_projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES platform_user_refs(user_id),
  name text NOT NULL,
  status text NOT NULL CHECK (status IN ('active', 'archived', 'deleted')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS canvas_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES canvas_projects(id),
  owner_user_id uuid NOT NULL REFERENCES platform_user_refs(user_id),
  capability text NOT NULL CHECK (capability IN ('text', 'image', 'video', 'audio', 'music', 'understanding_moderation')),
  platform_model_id text NOT NULL,
  model_alias text NOT NULL,
  price_version text NOT NULL,
  reservation_id uuid NOT NULL,
  status text NOT NULL CHECK (status IN ('created', 'reserved', 'queued', 'running', 'succeeded', 'failed', 'cancelled', 'refunded')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS canvas_task_nodes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES canvas_tasks(id),
  node_key text NOT NULL,
  status text NOT NULL CHECK (status IN ('created', 'running', 'succeeded', 'failed', 'cancelled', 'refunded')),
  input jsonb NOT NULL DEFAULT '{}'::jsonb,
  output jsonb,
  actual_usage bigint CHECK (actual_usage IS NULL OR actual_usage >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (task_id, node_key)
);

CREATE TABLE IF NOT EXISTS asset_refs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES platform_user_refs(user_id),
  project_id uuid REFERENCES canvas_projects(id),
  provider text NOT NULL CHECK (provider IN ('local', 'cos', 'oss', 's3', 'minio')),
  object_key text NOT NULL,
  media_type text NOT NULL,
  byte_size bigint NOT NULL CHECK (byte_size >= 0),
  retention_until timestamptz,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, object_key)
);

CREATE TABLE IF NOT EXISTS readonly_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES canvas_projects(id),
  owner_user_id uuid NOT NULL REFERENCES platform_user_refs(user_id),
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_canvas_tasks_owner_status
  ON canvas_tasks (owner_user_id, status, created_at);
CREATE INDEX IF NOT EXISTS idx_asset_refs_owner_retention
  ON asset_refs (owner_user_id, retention_until);

COMMIT;
