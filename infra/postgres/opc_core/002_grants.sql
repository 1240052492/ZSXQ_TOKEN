BEGIN;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO zsxq_opc_core_runtime, zsxq_opc_core_migration;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO zsxq_opc_core_runtime;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO zsxq_opc_core_migration;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO zsxq_opc_core_runtime, zsxq_opc_core_migration;
ALTER DEFAULT PRIVILEGES FOR ROLE zsxq_opc_core_owner IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO zsxq_opc_core_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE zsxq_opc_core_owner IN SCHEMA public GRANT ALL ON TABLES TO zsxq_opc_core_migration;
COMMIT;
