-- Test function get_migration_script_path()
\i tests/sql/setup/init.sql

BEGIN;
SELECT plan(2);

SET ROLE __pgmigrations_testuser;

SELECT is(
    pgmigrations.get_migration_script_path('migration_dir','up'),
    'migrations/contrib_regression/migration_dir/up.sql',
    'get_migration_script_path() should return relative path the script'
);

PREPARE my_query AS
    SELECT pgmigrations.get_migration_script_path('migration_dir','foobar' );

SELECT throws_ok(
    'my_query',
    'Invalid script type "foobar"',
    'calling get_migration_script_path() with invalid script type should throw exception'
);
DEALLOCATE my_query;

SELECT * FROM finish();
ROLLBACK;