\echo Use "CREATE EXTENSION pgmigrations" to load this file.\quit

/*

https://github.com/rimantas-cernauskas/pgmigrations/issues/6

Function to apply single migration upgrade script #6

Currently pgmigrations.upgrade() will apply all not yet applied( attempted )
migrations ( pgmigrations.rollback_migration() is already for single migration).

To make testing upgrades/downgrades and backwards compatibility,
it would be better to have function which only applies single migration.

*/

CREATE OR REPLACE VIEW pgmigrations.migration_scripts AS
	SELECT
	     m.name     AS migration
	    ,s.script   AS script
	    ,s.id       AS script_id
	    ,t.name 	AS script_type
	FROM
	    pgmigrations.migrations m
	    LEFT OUTER JOIN pgmigrations.scripts s      ON s.migration_id = m.id
	    LEFT OUTER JOIN pgmigrations.script_types t ON t.id = s.type_id
	ORDER BY migration
;

/*
	pgmigrations.execute_script(
		script_id INTEGER -- script id to execute
	)

	executes script and adds log record,
	returns TRUE on success, FALSE on failure.
*/

CREATE OR REPLACE FUNCTION
	pgmigrations.execute_script(
		_script_id INTEGER
	)
	RETURNS BOOLEAN
AS $$
DECLARE
    success         BOOLEAN;
    error_message   TEXT;
    script			TEXT;
BEGIN

	SELECT ms.script INTO script
	FROM pgmigrations.migration_scripts ms
	WHERE ms.script_id = _script_id;

	-- execute script
	BEGIN
        EXECUTE script;
        success = TRUE;

        EXCEPTION WHEN others THEN
            error_message   = SQLERRM;
            success         = FALSE;
    END;

    -- update script log
    PERFORM pgmigrations.add_script_log_record(
         _script_id
        ,success
        ,error_message
    );

    RETURN success;
END;
$$ 	LANGUAGE plpgsql;

/*
    pgmigrations.upgrade_migration(
        migration TEXT  -- migration name
    )
    RETURNS TRUE on success, false on error
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.upgrade_migration(
        _migration TEXT
    )
    RETURNS BOOLEAN
AS $$
DECLARE
    success         BOOLEAN;
    script_id       INTEGER;
BEGIN

    SELECT ms.script_id FROM pgmigrations.migration_scripts ms
        WHERE ms.migration = _migration AND ms.script_type = 'up'
        INTO script_id;

    SELECT pgmigrations.execute_script(
        script_id
    ) INTO success;

    RETURN success;
END
$$  LANGUAGE plpgsql;

/*
    pgmigrations.rollback_migration(
        migration TEXT  -- migration name
    )
    RETURNS TRUE on success, false on error
    Creates a log entry.

*/

CREATE OR REPLACE FUNCTION
    pgmigrations.rollback_migration(
        _migration TEXT
    )
    RETURNS BOOLEAN
AS $$
DECLARE
    success         BOOLEAN;
    script_id       INTEGER;
BEGIN

    SELECT ms.script_id FROM pgmigrations.migration_scripts ms
        WHERE ms.migration = _migration AND ms.script_type = 'down'
        INTO script_id;

    SELECT pgmigrations.execute_script(
        script_id
    ) INTO success;

    RETURN success;
END
$$  LANGUAGE plpgsql;

/*
    pgmigrations.apply_migrations();

    executes not yet applied migrations, returns TRUE on success,
    throws an exception otherwise.

*/

CREATE OR REPLACE FUNCTION
    pgmigrations.apply_migrations()
    RETURNS BOOLEAN
AS $$
DECLARE
    migration_rec   RECORD;
BEGIN
    -- loop through not applied migrations and execute them
    FOR migration_rec IN
        SELECT migration_name
        FROM pgmigrations.pending_upgrades
    LOOP

        PERFORM pgmigrations.upgrade_migration(
            migration_rec.migration_name
        );

    END LOOP;
    RETURN TRUE;
END
$$  LANGUAGE plpgsql;

/*
    pgmigrations.grant_privileges(
        role TEXT   -- role name to grant privileges to
    )

    Grants required usage privileges for the given user
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.grant_privileges(
        _role TEXT
    )
    RETURNS BOOLEAN
AS $$
BEGIN

    EXECUTE 'GRANT USAGE ON SCHEMA pgmigrations TO '             || _role;
    EXECUTE 'GRANT SELECT ON pgmigrations.migrations_info TO '   || _role;
    EXECUTE 'GRANT SELECT ON pgmigrations.pending_upgrades  TO ' || _role;
    EXECUTE 'GRANT SELECT ON pgmigrations.migration_scripts TO ' || _role;

    RETURN TRUE;
END
$$  LANGUAGE plpgsql;

/*

    pgmigrations.revoke_privileges(
        role TEXT -- role name to revoke privileges from
    );

*/

CREATE OR REPLACE FUNCTION
    pgmigrations.revoke_privileges(
        _role TEXT
    )
    RETURNS BOOLEAN
AS $$
BEGIN
    EXECUTE 'REVOKE ALL PRIVILEGES ON pgmigrations.migrations_info FROM '   || _role;
    EXECUTE 'REVOKE ALL PRIVILEGES ON pgmigrations.pending_upgrades FROM '  || _role;
    EXECUTE 'REVOKE ALL PRIVILEGES ON pgmigrations.migration_scripts FROM ' || _role;
    EXECUTE 'REVOKE ALL PRIVILEGES ON SCHEMA pgmigrations FROM '            || _role;

    RETURN TRUE;
END
$$  LANGUAGE plpgsql;

-- Drop deprecated view
ALTER EXTENSION pgmigrations DROP VIEW pgmigrations.downgrade_scripts;
DROP VIEW IF EXISTS pgmigrations.downgrade_scripts;