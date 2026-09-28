-- Fresh-cluster bootstrap only. Run with psql -X -v ON_ERROR_STOP=1 as a cluster
-- administrator after replacing every CHANGEME value through a secret manager.
-- Do not apply to an existing cluster without reconciling infra/postgres roles.
-- CREATE DATABASE cannot run inside a transaction block.

CREATE ROLE zsxq_new_api_owner NOLOGIN;
CREATE ROLE zsxq_new_api_migration LOGIN NOINHERIT PASSWORD 'CHANGEME_NEW_API_MIGRATION';
CREATE ROLE zsxq_new_api_runtime LOGIN PASSWORD 'CHANGEME_NEW_API_RUNTIME';
GRANT zsxq_new_api_owner TO zsxq_new_api_migration;

CREATE ROLE zsxq_opc_core_owner NOLOGIN;
CREATE ROLE zsxq_opc_core_migration LOGIN NOINHERIT PASSWORD 'CHANGEME_OPC_CORE_MIGRATION';
CREATE ROLE zsxq_opc_core_runtime LOGIN PASSWORD 'CHANGEME_OPC_CORE_RUNTIME';
GRANT zsxq_opc_core_owner TO zsxq_opc_core_migration;

CREATE ROLE zsxq_super_canvas_owner NOLOGIN;
CREATE ROLE zsxq_super_canvas_migration LOGIN NOINHERIT PASSWORD 'CHANGEME_SUPER_CANVAS_MIGRATION';
CREATE ROLE zsxq_super_canvas_runtime LOGIN PASSWORD 'CHANGEME_SUPER_CANVAS_RUNTIME';
GRANT zsxq_super_canvas_owner TO zsxq_super_canvas_migration;

CREATE DATABASE new_api OWNER zsxq_new_api_owner;
CREATE DATABASE opc_core OWNER zsxq_opc_core_owner;
CREATE DATABASE super_canvas OWNER zsxq_super_canvas_owner;

REVOKE ALL ON DATABASE new_api, opc_core, super_canvas FROM PUBLIC;
GRANT CONNECT ON DATABASE new_api TO zsxq_new_api_migration, zsxq_new_api_runtime;
GRANT CONNECT ON DATABASE opc_core TO zsxq_opc_core_migration, zsxq_opc_core_runtime;
GRANT CONNECT ON DATABASE super_canvas TO zsxq_super_canvas_migration, zsxq_super_canvas_runtime;

\connect new_api
ALTER SCHEMA public OWNER TO zsxq_new_api_owner;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO zsxq_new_api_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE zsxq_new_api_owner IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO zsxq_new_api_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE zsxq_new_api_owner IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO zsxq_new_api_runtime;

\connect opc_core
ALTER SCHEMA public OWNER TO zsxq_opc_core_owner;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO zsxq_opc_core_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE zsxq_opc_core_owner IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO zsxq_opc_core_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE zsxq_opc_core_owner IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO zsxq_opc_core_runtime;

\connect super_canvas
ALTER SCHEMA public OWNER TO zsxq_super_canvas_owner;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO zsxq_super_canvas_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE zsxq_super_canvas_owner IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO zsxq_super_canvas_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE zsxq_super_canvas_owner IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO zsxq_super_canvas_runtime;
