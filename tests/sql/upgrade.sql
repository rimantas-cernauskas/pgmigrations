-- Test function pgmigrations.upgrade
\i tests/sql/setup/init.sql
BEGIN;
SELECT plan(1);
SET ROLE __pgmigrations_testuser;

-- setup mocks
\i tests/sql/setup/load_migrations_mocks.sql

PREPARE my_query AS
    SELECT
    *
    FROM pgmigrations.upgrade();

PREPARE my_expect AS
    SELECT * FROM (
        VALUES (
             '00'
            ,'CREATE TABLE foo( id SERIAL PRIMARY KEY );'
            ,NOW()
            ,TRUE
            ,NULL
            ,E'DROP TABLE foo;'
            ,NULL::TIMESTAMP WITH TIME ZONE
            ,NULL::BOOLEAN
            ,NULL
        ),(
             '02'
            ,'ALTER TABLE foo ADD COLUMN new_column TEXT NOT NULL;'
            ,NOW()
            ,TRUE
            ,NULL
            ,NULL
            ,NULL
            ,NULL::BOOLEAN
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

SELECT results_eq(
     'my_query'
    ,'my_expect'
    ,'pgmigrations.upgrade() should return pgmigrations.migrations_info() query'
);

DEALLOCATE my_query;
DEALLOCATE my_expect;

SELECT * FROM finish();
ROLLBACK;
