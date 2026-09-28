# new_api migrations

New API currently owns its upstream schema through GORM `AutoMigrate`. Do not
recreate its tables here. Once startup DDL is separated from runtime, put only
approved integration additions in ordered `000001_name.up.sql` and
`000001_name.down.sql` pairs. Run against `new_api` as the migration login after
`SET ROLE zsxq_new_api_owner`; never point this directory at another database.
