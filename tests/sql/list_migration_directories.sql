-- Test function pgmigrations.list_migration_directories()
\i tests/sql/setup/init.sql

BEGIN;
SELECT plan(2);

-- setup mocks
\i tests/sql/setup/list_migration_directories_mocks.sql

SET ROLE __pgmigrations_testuser;

PREPARE my_query AS
    SELECT migration_directory
        FROM pgmigrations.list_migration_directories()
        ORDER BY migration_directory;

PREPARE my_expect AS
    SELECT migration_directory
        FROM (
            VALUES('00'),('01'),('02')
        ) t( migration_directory );

SELECT results_eq(
    'my_query',
    'my_expect',
    'list_migration_directories() should return expected migration directories'
);
DEALLOCATE my_query;
DEALLOCATE my_expect;

-- setup response from mocked ls_dir function
TRUNCATE TABLE _mock_ls_dir;

PREPARE my_query AS
    SELECT migration_directory
        FROM pgmigrations.list_migration_directories()
        ORDER BY migration_directory;

SELECT is_empty(
    'my_query'
    ,'list_migration_directories() should return empty table when migrations directory does not exist'
);
DEALLOCATE my_query;

SELECT * FROM finish();
ROLLBACK;