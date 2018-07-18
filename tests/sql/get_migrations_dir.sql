-- Testing function pgmigrations.get_migrations_dir()
\i tests/sql/setup/init.sql

BEGIN;
SELECT plan(1);

SET ROLE __pgmigrations_testuser;

SELECT is(
     pgmigrations.get_migrations_dir()
    ,'migrations/contrib_regression'
    ,'should get database specific migrations directory'
);

SELECT * FROM finish();
ROLLBACK;