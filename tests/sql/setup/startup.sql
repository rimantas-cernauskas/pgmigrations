/*
    ================================
    Setup test roles and permissions
    ================================
*/

CREATE EXTENSION pgtap;

CREATE ROLE __pgmigrations_superuser  WITH LOGIN SUPERUSER;
CREATE ROLE __pgmigrations_testuser   WITH LOGIN NOSUPERUSER;

-- setup permissions
SELECT pgmigrations.grant_privileges( '__pgmigrations_superuser' );
SELECT pgmigrations.grant_privileges( '__pgmigrations_testuser' );
