-- Run as PostgreSQL cluster admin. Replace database names only through the
-- deployment environment; never commit passwords or permanent credentials.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zsxq_opc_core_runtime') THEN
    CREATE ROLE zsxq_opc_core_runtime NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zsxq_super_canvas_runtime') THEN
    CREATE ROLE zsxq_super_canvas_runtime NOLOGIN;
  END IF;
END
$$;

-- Apply these grants while connected to each target database. The role names
-- are intentionally separate so a canvas process cannot write opc_core.
-- new_api grants are deliberately absent: New API owns that database.

-- opc_core:
-- GRANT CONNECT ON DATABASE opc_core TO zsxq_opc_core_runtime;
-- GRANT USAGE ON SCHEMA public TO zsxq_opc_core_runtime;
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO zsxq_opc_core_runtime;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO zsxq_opc_core_runtime;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO zsxq_opc_core_runtime;

-- super_canvas:
-- GRANT CONNECT ON DATABASE super_canvas TO zsxq_super_canvas_runtime;
-- GRANT USAGE ON SCHEMA public TO zsxq_super_canvas_runtime;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO zsxq_super_canvas_runtime;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO zsxq_super_canvas_runtime;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO zsxq_super_canvas_runtime;
