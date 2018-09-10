-- Test function pgmigrations.rollback_migration
\i tests/sql/setup/init.sql
BEGIN;
SELECT plan(7);
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

SELECT is(
    pgmigrations.add_migration(
         '01'
        ,'CREATE TABLE table1( id SERIAL );'
        ,'DROP TABLE table1;'
    )
    ,TRUE
    ,'should add migration "01"'
);

-- upgrade first migration
SELECT is(
     pgmigrations.upgrade_migration( '00' )
    ,TRUE
    ,'upgrade_migration() should return TRUE on successful run'
);

-- check that migration was actually executed
-- migration 00
SELECT has_table('table0');
SELECT has_column('table0', 'id');

-- and that 01 migration was not executed
SELECT hasnt_table( 'table1' );

-- check log
PREPARE my_query AS
    SELECT
         migration
        ,up_run
        ,up_success
        ,up_error
    FROM pgmigrations.migrations_info
    ORDER BY migration ASC;

PREPARE my_expect AS
    SELECT * FROM (
        VALUES (
             '00'
            ,NOW()
            ,TRUE
            ,NULL
        ),
        (
            '01'
            ,NULL
            ,NULL
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

SELECT * FROM finish();
ROLLBACK;