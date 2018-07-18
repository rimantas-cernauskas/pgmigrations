-- Test function pgmigrations.apply_migrations
\i tests/sql/setup/init.sql
BEGIN;
SELECT plan(14);
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

-- add migration with syntax error
SELECT is(
    pgmigrations.add_migration(
         '01'
        ,'CREATE TALBE table1( id SERIAL );'
        ,'DROP TABLE table1;'
    )
    ,TRUE
    ,'should add migration "01"'
);

-- add another valid migration
SELECT is(
    pgmigrations.add_migration(
         '02'
        ,'CREATE TABLE table2( id SERIAL );'
    )
    ,TRUE
    ,'should add migration "02"'
);

-- test appply_migrations()
SET ROLE __pgmigrations_testuser;
SELECT is(
     pgmigrations.apply_migrations()
    ,TRUE
    ,'apply_migrations() should return TRUE on successful run'
);

PREPARE my_query AS
    SELECT
         migration
        , up_run
        , up_success
        , up_error
    FROM pgmigrations.migrations_info
    ORDER BY migration ASC;

PREPARE my_expect AS
    SELECT * FROM (
        VALUES (
             '00'
            ,NOW()
            ,TRUE
            ,NULL
        ),(
             '01'
            ,NOW()
            ,FALSE
            ,'syntax error at or near "TALBE"'
        ),(
             '02'
            ,NOW()
            ,TRUE
            ,NULL
        )
    )
    t(
         migration
        ,up_run
        ,up_success
        ,up_error
    )
;

SELECT results_eq(
     'my_query'
    ,'my_expect'
    ,'should get expected migrations info'
);
DEALLOCATE my_query;
DEALLOCATE my_expect;

-- check that migrations were actually applied
-- migration 00
SELECT has_table('table0');
SELECT has_column('table0', 'id');
-- migration 02
SELECT has_table('table2');
SELECT has_column('table2', 'id');

-- setup new migration
SET ROLE __pgmigrations_superuser;
SELECT is(
    pgmigrations.add_migration(
         '03'
        ,'CREATE TABLE table3( id SERIAL );'
        ,'DROP TABLE table3;'
    )
    ,TRUE
    ,'should add migration "03"'
);

-- Test apply_migrations()
SET ROLE __pgmigrations_testuser;
SELECT is(
     pgmigrations.apply_migrations()
    ,TRUE
    ,'apply_migrations() should return TRUE on successful run'
);

-- Check logs
PREPARE my_query AS
    SELECT
         migration
        , up_run
        , up_success
        , up_error
    FROM pgmigrations.migrations_info
    WHERE migration = '03'
    ORDER BY migration ASC;

PREPARE my_expect AS
    SELECT * FROM (
        VALUES (
             '03'
            ,NOW()
            ,TRUE
            ,NULL
        )
    )
    t(
         migration
        ,up_run
        ,up_success
        ,up_error
    )
;

SELECT results_eq(
     'my_query'
    ,'my_expect'
    ,'should get expected migrations info'
);
DEALLOCATE my_query;
DEALLOCATE my_expect;

-- check that new table has been created
SELECT has_table('table3');
SELECT has_column('table3', 'id');

SELECT * FROM finish();
ROLLBACK;