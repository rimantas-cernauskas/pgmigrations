-- Test function pgmigrations.rollback_migration
\i tests/sql/setup/init.sql
BEGIN;
SELECT plan(9);
SET ROLE __pgmigrations_testuser;

-- Setup migration scripts
SET ROLE __pgmigrations_superuser;
SELECT is(
    pgmigrations.add_migration(
         '00'
        ,'CREATE TABLE table0( id SERIAL );'
        ,'DROP TABLE table0;'
    )
    ,TRUE
    ,'should add migration "00"'
);

-- Test rollback_migrations() error
SET ROLE __pgmigrations_testuser;
SELECT is(
     pgmigrations.rollback_migration('00')
    ,FALSE
    ,'rollback_migration() should return FALSE on unsuccessful run'
);

PREPARE my_query AS
    SELECT
         migration
        ,down_run
        ,down_success
        ,down_error
    FROM pgmigrations.migrations_info
    ORDER BY migration ASC;

PREPARE my_expect AS
    SELECT * FROM (
        VALUES (
             '00'
            ,NOW()
            ,FALSE
            ,'table "table0" does not exist'
        )
    )
    t(
         migration
        ,down_run
        ,dwon_success
        ,down_error
    )
;

SELECT results_eq(
     'my_query'
    ,'my_expect'
    ,'should get expected migrations info'
);
DEALLOCATE my_query;
DEALLOCATE my_expect;


-- apply migration, so it could be rolled back
SELECT is(
     pgmigrations.apply_migrations()
    ,TRUE
    ,'apply_migrations() should return TRUE'
);

-- check that migrations were actually applied
-- migration 00
SELECT has_table('table0');
SELECT has_column('table0', 'id');

-- rollback migration
SELECT is(
    pgmigrations.rollback_migration(
        '00'
    )
    ,TRUE
    ,'rollback_migration() should return TRUE on successful rollback'
);

-- check log
PREPARE my_query AS
    SELECT
         migration
        ,down_run
        ,down_success
        ,down_error
    FROM pgmigrations.migrations_info
    ORDER BY migration ASC;

PREPARE my_expect AS
    SELECT * FROM (
        VALUES (
             '00'
            ,NOW()
            ,TRUE
            ,NULL
        )
    )
    t(
         migration
        ,down_run
        ,dwon_success
        ,down_error
    )
;

SELECT results_eq(
     'my_query'
    ,'my_expect'
    ,'should get expected migrations info'
);
DEALLOCATE my_query;
DEALLOCATE my_expect;

-- check that table has been deleted
SELECT hasnt_table('table0');

SELECT * FROM finish();
ROLLBACK;