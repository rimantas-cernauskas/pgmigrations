-- Test function pgmigrations.config()
\i tests/sql/setup/init.sql

BEGIN;
SELECT plan(8);

SET ROLE __pgmigrations_superuser;
SELECT is(
    pgmigrations.config('foo','bar'),
    TRUE,
    'superuser should be able to create new config entry'
);
SELECT is(
    pgmigrations.config('foo'),
    'bar',
    'superuser should be able to read existing config entry'
);
SELECT is(
    pgmigrations.config('foo','baz'),
    TRUE,
    'superuser should be able to update existing config entry'
);
SELECT is(
    pgmigrations.config('foo'),
    'baz',
    'value should be updated'
);
-- exception thrown when reading non existing entry
PREPARE my_query AS SELECT pgmigrations.config('bar');
SELECT throws_ok(
    'my_query',
    'Missing configuration for "bar"',
    'should throw exception when accessing non existing value'
);
DEALLOCATE my_query;

SET ROLE __pgmigrations_superuser;
SELECT is(
    pgmigrations.config('foo','bar'),
    TRUE,
    'setup - add expected configuration entry'
);
SET ROLE __pgmigrations_testuser;

SELECT is(
    pgmigrations.config('foo'),
    'bar',
    'unprivileged user should be able to read existing config entry'
);

PREPARE my_query AS SELECT pgmigrations.config('foo','bar');
SELECT throws_ok(
    'my_query',
    'permission denied for relation config',
    'should throw exception when attempting to create config option as unprivileged user');
DEALLOCATE my_query;

SELECT * FROM finish();
ROLLBACK;
