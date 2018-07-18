-- Test function pgmigrations.read_file
\i tests/sql/setup/init.sql

/*

This script relieas on the existence of the PG_VERSION file

*/

BEGIN;
SELECT plan(3);

SET ROLE __pgmigrations_testuser;

PREPARE my_query AS
    SELECT pgmigrations.read_file( 'PG_VERSION' );

SELECT throws_ok(
    'my_query'
    ,'must be superuser to call read_file()'
    ,'read_file() should throw exception when called as unprivileged user'
);

DEALLOCATE my_query;

SET ROLE __pgmigrations_superuser;

SELECT matches(
     pgmigrations.read_file( 'PG_VERSION')
    ,'\d+'
    ,'read_file() should return file content when called as super user'
);

SELECT is(
     pgmigrations.read_file( 'should_not_exist')
    ,NULL
    ,'read_file() should return NULL when file does not exist'
);

SELECT * FROM finish();
ROLLBACK;