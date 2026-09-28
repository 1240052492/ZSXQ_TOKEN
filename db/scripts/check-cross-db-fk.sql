-- Run once against each database with psql -X -v ON_ERROR_STOP=1 -f this-file.
-- PostgreSQL cannot create a native FK across databases. This catalog gate also
-- rejects FDW bridges to sibling databases and foreign-table FK endpoints.
DO $check$
DECLARE
  violations text;
BEGIN
  SELECT string_agg(issue, E'\n' ORDER BY issue) INTO violations
  FROM (
    SELECT format('foreign key %I.%I uses a foreign table', n.nspname, c.conname) AS issue
    FROM pg_constraint c
    JOIN pg_class source_table ON source_table.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = source_table.relnamespace
    JOIN pg_class target_table ON target_table.oid = c.confrelid
    WHERE c.contype = 'f'
      AND (source_table.relkind = 'f' OR target_table.relkind = 'f')
    UNION ALL
    SELECT format('foreign server %I targets sibling database %s', s.srvname, o.option_value)
    FROM pg_foreign_server s
    CROSS JOIN LATERAL pg_options_to_table(s.srvoptions) o
    WHERE o.option_name = 'dbname'
      AND o.option_value IN ('new_api', 'opc_core', 'super_canvas')
      AND o.option_value <> current_database()
  ) issues;

  IF violations IS NOT NULL THEN
    RAISE EXCEPTION 'Cross-database reference gate failed in %: %', current_database(), violations;
  END IF;

  RAISE NOTICE 'No catalog-visible cross-database FK or sibling-database FDW bridge in %', current_database();
END
$check$;
