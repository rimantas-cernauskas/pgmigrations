SELECT pgmigrations.revoke_privileges('__pgmigrations_testuser');
SELECT pgmigrations.revoke_privileges('__pgmigrations_superuser');

DROP EXTENSION pgmigrations;

-- Remove test roles
DROP ROLE __pgmigrations_testuser;
DROP ROLE __pgmigrations_superuser;