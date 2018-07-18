-- Test function pgmigrations.load_migrations
\i tests/sql/setup/init.sql
BEGIN;
SELECT plan(4);

-- setup mocks
\i tests/sql/setup/load_migrations_mocks.sql

SET ROLE __pgmigrations_testuser;

SELECT is(
     pgmigrations.load_migrations()
    ,TRUE
    ,'load_migrations() should return TRUE on successful load'
);
PREPARE my_query AS
    SELECT migration ,up ,down
    FROM pgmigrations.migrations_info
;

PREPARE my_expect AS
    SELECT * FROM (
        VALUES (
             '00'
            ,'CREATE TABLE foo( id SERIAL PRIMARY KEY );'
            ,'DROP TABLE foo;'
        ),(
             '02'
            ,'ALTER TABLE foo ADD COLUMN new_column TEXT NOT NULL;'
            ,NULL
        )
    )
    t(
         migration
        ,up
        ,down
    )
;

SELECT results_eq(
     'my_query'
    ,'my_expect'
    ,'should have migrations added'
);

SELECT is(
     pgmigrations.load_migrations()
    ,TRUE
    ,'load_migrations() re-run should return TRUE on successful load'
);

SELECT results_eq(
     'my_query'
    ,'my_expect'
    ,'should have same migrations list'
);
DEALLOCATE my_expect;
DEALLOCATE my_query;

SELECT * FROM finish();
ROLLBACK;
