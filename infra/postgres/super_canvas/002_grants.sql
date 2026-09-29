BEGIN;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO zsxq_super_canvas_runtime, zsxq_super_canvas_migration;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO zsxq_super_canvas_runtime;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO zsxq_super_canvas_migration;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO zsxq_super_canvas_runtime, zsxq_super_canvas_migration;
ALTER DEFAULT PRIVILEGES FOR ROLE zsxq_super_canvas_owner IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO zsxq_super_canvas_runtime;
ALTER DEFAULT PRIVILEGES FOR ROLE zsxq_super_canvas_owner IN SCHEMA public GRANT ALL ON TABLES TO zsxq_super_canvas_migration;
COMMIT;
