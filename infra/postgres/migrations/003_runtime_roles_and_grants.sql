-- Migration 003: Runtime roles and permission grants
-- Purpose: Create production runtime users and grant minimal required permissions
-- Dependencies: 001_init.sql (both databases), 002_migrate_payment_schemas.sql
-- Idempotent: YES (uses IF NOT EXISTS and conditional grants)

-- =============================================================================
-- PART 1: Create runtime roles (cluster-level)
-- =============================================================================

-- Canvas application runtime user (read/write super_canvas only)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'canvas_app') THEN
        CREATE ROLE canvas_app LOGIN;
        RAISE NOTICE 'Created role: canvas_app';
    ELSE
        RAISE NOTICE 'Role already exists: canvas_app';
    END IF;
END
$$;

-- OPC service runtime user (read/write opc_core only)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'opc_service') THEN
        CREATE ROLE opc_service LOGIN;
        RAISE NOTICE 'Created role: opc_service';
    ELSE
        RAISE NOTICE 'Role already exists: opc_service';
    END IF;
END
$$;

-- Read-only admin user (read all databases for monitoring/debugging)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'admin_ro') THEN
        CREATE ROLE admin_ro LOGIN;
        RAISE NOTICE 'Created role: admin_ro';
    ELSE
        RAISE NOTICE 'Role already exists: admin_ro';
    END IF;
END
$$;

-- Migration executor (DDL operations only, not for runtime)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'db_migrator') THEN
        CREATE ROLE db_migrator LOGIN;
        RAISE NOTICE 'Created role: db_migrator';
    ELSE
        RAISE NOTICE 'Role already exists: db_migrator';
    END IF;
END
$$;

-- =============================================================================
-- PART 2: Grant CONNECT privileges
-- =============================================================================

-- Canvas app can only connect to super_canvas
GRANT CONNECT ON DATABASE super_canvas TO canvas_app;

-- OPC service can only connect to opc_core
GRANT CONNECT ON DATABASE opc_core TO opc_service;

-- Admin read-only can connect to all databases
GRANT CONNECT ON DATABASE super_canvas TO admin_ro;
GRANT CONNECT ON DATABASE opc_core TO admin_ro;
GRANT CONNECT ON DATABASE new_api TO admin_ro;

-- Migrator can connect to all databases
GRANT CONNECT ON DATABASE super_canvas TO db_migrator;
GRANT CONNECT ON DATABASE opc_core TO db_migrator;
GRANT CONNECT ON DATABASE new_api TO db_migrator;

-- =============================================================================
-- PART 3: super_canvas permissions (execute in super_canvas database)
-- =============================================================================

\c super_canvas

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO canvas_app;
GRANT USAGE ON SCHEMA public TO admin_ro;
GRANT USAGE ON SCHEMA public TO db_migrator;

-- Canvas app: read/write on all tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO canvas_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO canvas_app;

-- Future tables (for new migrations)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO canvas_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO canvas_app;

-- Admin read-only: SELECT only
GRANT SELECT ON ALL TABLES IN SCHEMA public TO admin_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO admin_ro;

-- Migrator: full DDL and DML
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO db_migrator;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO db_migrator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON TABLES TO db_migrator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON SEQUENCES TO db_migrator;

-- =============================================================================
-- PART 4: opc_core permissions (execute in opc_core database)
-- =============================================================================

\c opc_core

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO opc_service;
GRANT USAGE ON SCHEMA public TO admin_ro;
GRANT USAGE ON SCHEMA public TO db_migrator;

-- OPC service: read/write on all tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO opc_service;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO opc_service;

-- Future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO opc_service;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO opc_service;

-- Admin read-only: SELECT only
GRANT SELECT ON ALL TABLES IN SCHEMA public TO admin_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO admin_ro;

-- Migrator: full DDL and DML
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO db_migrator;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO db_migrator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON TABLES TO db_migrator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON SEQUENCES TO db_migrator;

-- =============================================================================
-- PART 5: new_api permissions (execute in new_api database)
-- =============================================================================

\c new_api

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO admin_ro;
GRANT USAGE ON SCHEMA public TO db_migrator;

-- Admin read-only: SELECT only
GRANT SELECT ON ALL TABLES IN SCHEMA public TO admin_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO admin_ro;

-- Migrator: full DDL and DML
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO db_migrator;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO db_migrator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON TABLES TO db_migrator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON SEQUENCES TO db_migrator;

-- NOTE: new_api runtime application user should be created and managed
-- by the New API service itself. This migration does NOT grant permissions
-- to any new_api runtime role.

-- =============================================================================
-- PART 6: Verification queries (for testing)
-- =============================================================================

-- Run these queries to verify permissions:
--
-- Check role existence:
-- SELECT rolname, rolcanlogin FROM pg_roles
-- WHERE rolname IN ('canvas_app', 'opc_service', 'admin_ro', 'db_migrator');
--
-- Check database connect privileges:
-- SELECT datname, grantee, privilege_type
-- FROM information_schema.database_privileges
-- WHERE grantee IN ('canvas_app', 'opc_service', 'admin_ro', 'db_migrator')
-- ORDER BY datname, grantee;
--
-- Check table privileges (run in each database):
-- SELECT table_schema, table_name, grantee, privilege_type
-- FROM information_schema.table_privileges
-- WHERE grantee IN ('canvas_app', 'opc_service', 'admin_ro', 'db_migrator')
-- ORDER BY table_name, grantee, privilege_type;

-- Migration complete
DO $$
BEGIN
    RAISE NOTICE '✓ Migration 003 complete: runtime roles and grants configured';
    RAISE NOTICE '  canvas_app: CONNECT super_canvas, R/W all tables';
    RAISE NOTICE '  opc_service: CONNECT opc_core, R/W all tables';
    RAISE NOTICE '  admin_ro: CONNECT all databases, SELECT all tables';
    RAISE NOTICE '  db_migrator: CONNECT all databases, full DDL/DML';
END
$$;
