# opc_core migrations

Add ordered `000001_name.up.sql` and `000001_name.down.sql` pairs here. The
initial migration must reconcile the existing `infra/postgres/opc_core/001_init.sql`
baseline before creating OPC session, workflow, run, asset and audit tables.
Run against `opc_core` as the migration login after `SET ROLE
zsxq_opc_core_owner`. Keep business references to New API as scalar IDs.
