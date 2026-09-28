# super_canvas migrations

Add ordered `000001_name.up.sql` and `000001_name.down.sql` pairs here. The
initial migration must reconcile the existing
`infra/postgres/super_canvas/001_init.sql` baseline before changes. Run against
`super_canvas` as the migration login after `SET ROLE
zsxq_super_canvas_owner`. Keep business references to New API as scalar IDs.
