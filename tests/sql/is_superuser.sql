-- Test function pgmigrations.is_superuser()
\i tests/sql/setup/init.sql

BEGIN;
SELECT plan(2);

SET ROLE __pgmigrations_testuser;
SELECT is(
     pgmigrations.is_superuser()
    , FALSE
    , 'should get FALSE for non superuser'
);

SET ROLE __pgmigrations_superuser;
SELECT is(
     pgmigrations.is_superuser()
    ,TRUE
    ,'should get TRUE for superuser'
);

SELECT * FROM finish();
ROLLBACK;
