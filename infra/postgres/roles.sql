-- Execute with psql as cluster administrator. This is a local/demo baseline;
-- passwords are never stored here and runtime roles are NOLOGIN group roles.
\set ON_ERROR_STOP on

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zsxq_new_api_owner') THEN CREATE ROLE zsxq_new_api_owner NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zsxq_new_api_migration') THEN CREATE ROLE zsxq_new_api_migration NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zsxq_new_api_runtime') THEN CREATE ROLE zsxq_new_api_runtime NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zsxq_opc_core_owner') THEN CREATE ROLE zsxq_opc_core_owner NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zsxq_opc_core_migration') THEN CREATE ROLE zsxq_opc_core_migration NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zsxq_opc_core_runtime') THEN CREATE ROLE zsxq_opc_core_runtime NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zsxq_super_canvas_owner') THEN CREATE ROLE zsxq_super_canvas_owner NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zsxq_super_canvas_migration') THEN CREATE ROLE zsxq_super_canvas_migration NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zsxq_super_canvas_runtime') THEN CREATE ROLE zsxq_super_canvas_runtime NOLOGIN; END IF;
END
$$;

SELECT format('CREATE DATABASE %I OWNER %I', 'new_api', 'zsxq_new_api_owner')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'new_api')\gexec
SELECT format('CREATE DATABASE %I OWNER %I', 'opc_core', 'zsxq_opc_core_owner')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'opc_core')\gexec
SELECT format('CREATE DATABASE %I OWNER %I', 'super_canvas', 'zsxq_super_canvas_owner')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'super_canvas')\gexec

GRANT CONNECT ON DATABASE new_api TO zsxq_new_api_runtime, zsxq_new_api_migration;
GRANT CONNECT ON DATABASE opc_core TO zsxq_opc_core_runtime, zsxq_opc_core_migration;
GRANT CONNECT ON DATABASE super_canvas TO zsxq_super_canvas_runtime, zsxq_super_canvas_migration;
