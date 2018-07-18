-- Test view pgmigrations.migrations_info
\i tests/sql/setup/init.sql
BEGIN;
SELECT plan(2);

SET ROLE __pgmigrations_testuser;

PREPARE my_query AS
    SELECT
         migration
        ,up
        ,up_run
        ,up_success
        ,up_error
        ,down
        ,down_run
        ,down_success
        ,down_error
    FROM pgmigrations.migrations_info
    ORDER BY migration ASC;

SELECT is_empty(
     'my_query'
    ,'select from migrations_info should return empty table when there are no migrations'
);

-- prepare test data
SET ROLE __pgmigrations_superuser;

INSERT INTO pgmigrations.migrations(name )
    VALUES
     ( 'test_migration_00')
    ,( 'test_migration_01')
    ,( 'test_migration_02')
;

INSERT INTO pgmigrations.scripts( migration_id, type_id, script )
    VALUES (
         ( SELECT id FROM pgmigrations.migrations WHERE name = 'test_migration_00')
        ,( SELECT id FROM pgmigrations.script_types WHERE name = 'up' )
        ,'up script 00'
    ),(
         ( SELECT id FROM pgmigrations.migrations WHERE name = 'test_migration_00')
        ,( SELECT id FROM pgmigrations.script_types WHERE name = 'down' )
        ,'down script 00'
    ),(
         ( SELECT id FROM pgmigrations.migrations WHERE name = 'test_migration_01')
        ,( SELECT id FROM pgmigrations.script_types WHERE name = 'up' )
        ,'up script 01'
    ),(
         ( SELECT id FROM pgmigrations.migrations WHERE name = 'test_migration_02')
        ,( SELECT id FROM pgmigrations.script_types WHERE name = 'up' )
        ,'up script 02'
    ),(
         ( SELECT id FROM pgmigrations.migrations WHERE name = 'test_migration_02')
        ,( SELECT id FROM pgmigrations.script_types WHERE name = 'down' )
        ,'down script 02'
    )
;

INSERT INTO pgmigrations.script_log( script_id, timestamp, success, error )
    VALUES(
        ( SELECT id FROM pgmigrations.scripts WHERE script = 'up script 00' )
       ,NOW()
       ,TRUE
       ,NULL
    ),(
        ( SELECT id FROM pgmigrations.scripts WHERE script = 'up script 01' )
       ,NOW() - INTERVAL '4 hour'
       ,FALSE
       ,'error 01 for up script 01'
    ),(
        ( SELECT id FROM pgmigrations.scripts WHERE script = 'up script 01' )
       ,NOW() - INTERVAL '1 hour'
       ,FALSE
       ,'error 03 for up script 01'
    ),(
        ( SELECT id FROM pgmigrations.scripts WHERE script = 'up script 01' )
       ,NOW() - INTERVAL '2 hour'
       ,FALSE
       ,'error 02 for up script 01'
    ),(
        ( SELECT id FROM pgmigrations.scripts WHERE script = 'up script 02' )
       ,NOW() - INTERVAL '12 hour'
       ,FALSE
       ,'error 01 for up script 02'
    ),(
        ( SELECT id FROM pgmigrations.scripts WHERE script = 'up script 02' )
       ,NOW() - INTERVAL '11 hour'
       ,FALSE
       ,'error 02 for up script 02'
    ),(
        ( SELECT id FROM pgmigrations.scripts WHERE script = 'up script 02' )
       ,NOW() - INTERVAL '10 hour'
       ,TRUE
       ,NULL
    ),(
        ( SELECT id FROM pgmigrations.scripts WHERE script = 'down script 02' )
       ,NOW() - INTERVAL '8 hour'
       ,FALSE
       ,'error 01 for down script 02'
    ),(
        ( SELECT id FROM pgmigrations.scripts WHERE script = 'down script 02' )
       ,NOW() - INTERVAL '6 hour'
       ,TRUE
       ,NULL
    )
;

PREPARE my_expect AS
    SELECT * FROM (
        VALUES (
             'test_migration_00'
            ,'up script 00'
            ,NOW()
            ,TRUE
            ,NULL
            ,'down script 00'
            ,NULL
            ,NULL
            ,NULL
        ),(
             'test_migration_01'
            ,'up script 01'
            ,NOW() - INTERVAL '1 hour'
            ,FALSE
            ,'error 03 for up script 01'
            ,NULL
            ,NULL
            ,NULL
            ,NULL
        ),(
             'test_migration_02'
            ,'up script 02'
            ,NOW() - INTERVAL '10 hour'
            ,TRUE
            ,NULL
            ,'down script 02'
            ,NOW() - INTERVAL '6 hour'
            ,TRUE
            ,NULL
        )
    )
    t(
         migration
        ,up
        ,up_run
        ,up_success
        ,up_error
        ,down
        ,down_run
        ,down_success
        ,down_error
    )
;

SET ROLE __pgmigrations_testuser;

SELECT results_eq(
    'my_query',
    'my_expect',
    'select from migrations_info view should return expected data'
);

DEALLOCATE my_query;
DEALLOCATE my_expect;

SELECT * FROM finish();
ROLLBACK;
