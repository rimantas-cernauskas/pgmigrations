\echo Use "CREATE EXTENSION pgmigrations" to load this file.\quit

-- setup
DO LANGUAGE plpgsql $$
DECLARE
BEGIN
    -- create pgmigrations schema
    RAISE NOTICE 'Creating pgmigrations';
    CREATE SCHEMA IF NOT EXISTS pgmigrations;

    -- create pgmigrations.settings table
    -- to store various configuration options
    RAISE NOTICE 'Creating settings table';
    CREATE TABLE IF NOT EXISTS pgmigrations.config(
         name  TEXT UNIQUE NOT NULL
        ,value TEXT NOT NULL
    );

    -- Mark table as extension config
    PERFORM pg_catalog.pg_extension_config_dump('pgmigrations.config', '');

    -- set default configuration
    RAISE NOTICE 'Populating settings';

    -- default migrations directory: 'pgmigrations'
    INSERT INTO pgmigrations.config(name, value)
    SELECT 'basedir', 'migrations'
    WHERE NOT EXISTS (
        SELECT name FROM pgmigrations.config WHERE name = 'basedir'
    );

    -- default migrations script file extension: '.sql'
    INSERT INTO pgmigrations.config(name, value)
    SELECT 'script_file_extension', '.sql'
    WHERE NOT EXISTS (
        SELECT name FROM pgmigrations.config WHERE name = 'script_file_extension'
    );

    -- default directory separator: '/'
    INSERT INTO pgmigrations.config(name, value)
    SELECT 'sep_dir', '/'
    WHERE NOT EXISTS (
        SELECT name FROM pgmigrations.config WHERE name = 'sep_dir'
    );

    -- default help command
    INSERT INTO pgmigrations.config(name, value)
    SELECT 'cmd_help', 'help'
    WHERE NOT EXISTS (
        SELECT name FROM pgmigrations.config WHERE name = 'cmd_help'
    );

    -- default help message
    INSERT INTO pgmigrations.config(name, value)
    SELECT 'msg_help', 'some help message'
    WHERE NOT EXISTS (
        SELECT name FROM pgmigrations.config WHERE name = 'msg_help'
    );

    -- create pgmigrations.script_types table
    -- for referencing different migration types ( up, down etc ).
    CREATE TABLE IF NOT EXISTS pgmigrations.script_types(
         id   SERIAL PRIMARY KEY
        ,name TEXT NOT NULL UNIQUE
    );

    -- add indexes to pgmigrations.script_types for name
    CREATE INDEX ON pgmigrations.script_types(name);

    -- add default migration types:
    --  * up
    --  * down
    INSERT INTO pgmigrations.script_types( name ) VALUES( 'up' ), ('down' );

    -- create pgmigrations.migrations table to store migration data
    CREATE TABLE IF NOT EXISTS pgmigrations.migrations(
         id             SERIAL PRIMARY KEY
        ,name           TEXT NOT NULL UNIQUE
        ,created        TIMESTAMP WITH TIME ZONE
                        NOT NULL
                        DEFAULT(current_timestamp)
    );

    -- Mark table as extension config
    PERFORM pg_catalog.pg_extension_config_dump('pgmigrations.migrations', '');

    -- create pgmigrations.scripts table to store up/down etc script
    -- content and reference to migration
    CREATE TABLE IF NOT EXISTS pgmigrations.scripts(
         id             SERIAL PRIMARY KEY
        ,migration_id   INTEGER NOT NULL
                        REFERENCES pgmigrations.migrations( id )
        ,type_id        INTEGER NOT NULL
                        REFERENCES pgmigrations.script_types( id )
        ,script         TEXT NOT NULL
        ,created        TIMESTAMP WITH TIME ZONE
                        NOT NULL
                        DEFAULT( current_timestamp)
    );

    -- create indexes for pgmigrations.scripts
    CREATE INDEX ON pgmigrations.scripts( type_id );
    CREATE INDEX ON pgmigrations.scripts( migration_id );

    -- create pgmigrations.script_log table to store state and
    -- execution log for migration script
    CREATE TABLE pgmigrations.script_log(
         id         SERIAL PRIMARY KEY
        ,script_id  INTEGER NOT NULL
        ,timestamp  TIMESTAMP WITH TIME ZONE
                    NOT NULL
                    DEFAULT(current_timestamp)
        ,success    BOOLEAN NOT NULL
        ,error      TEXT
    );

    -- add indexes for pgmigrations.script_log
    CREATE INDEX ON pgmigrations.script_log( timestamp );
    CREATE INDEX ON pgmigrations.script_log( script_id );

    -- create private pgmigrations._migrations_info view
    CREATE OR REPLACE VIEW pgmigrations.migrations_info AS
    SELECT
         m.name         AS migration
        ,u.script       AS up
        ,ulog.timestamp AS up_run
        ,ulog.success   AS up_success
        ,ulog.error     AS up_error
        ,d.script       AS down
        ,dlog.timestamp AS down_run
        ,dlog.success   AS down_success
        ,dlog.error     AS down_error
    FROM
        pgmigrations.migrations m

        -- up script and log
        LEFT OUTER JOIN pgmigrations.scripts u ON u.migration_id = m.id
            AND u.type_id = (
                SELECT id FROM pgmigrations.script_types WHERE name = 'up'
            )
        LEFT OUTER JOIN pgmigrations.script_log ulog ON
            ulog.id = (
                SELECT l.id FROM pgmigrations.script_log l WHERE l.script_id = u.id
                    ORDER BY l.timestamp DESC, l.id DESC LIMIT 1
            )

        -- down script and most recent log entry
        LEFT OUTER JOIN pgmigrations.scripts d ON d.migration_id = m.id
            AND d.type_id = (
                SELECT id FROM pgmigrations.script_types WHERE name = 'down'
            )
        LEFT JOIN pgmigrations.script_log dlog ON
            dlog.id = (
                SELECT l.id FROM pgmigrations.script_log l WHERE l.script_id = d.id
                    ORDER BY l.timestamp DESC, l.id DESC LIMIT 1
            )
    ;

    CREATE OR REPLACE VIEW pgmigrations.pending_upgrades AS
    SELECT
         m.name     AS migration_name
        ,m.id       AS migration_id
        ,u.script   AS up_script
        ,u.id       AS up_script_id
    FROM
        pgmigrations.migrations m
        LEFT OUTER JOIN pgmigrations.scripts u ON u.migration_id = m.id
            AND u.type_id = (
                SELECT id FROM pgmigrations.script_types WHERE name = 'up'
            )
        LEFT OUTER JOIN pgmigrations.script_log ulog ON
            ulog.id = (
                SELECT l.id FROM pgmigrations.script_log l WHERE l.script_id = u.id
                    ORDER BY l.timestamp DESC, l.id DESC LIMIT 1
            )
    WHERE ulog.id IS NULL
    ORDER BY migration_name
    ;

    CREATE OR REPLACE VIEW pgmigrations.downgrade_scripts AS
    SELECT
         m.name     AS migration_name
        ,m.id       AS migration_id
        ,d.script   AS downgrade_script
        ,d.id       AS downgrade_script_id
    FROM
        pgmigrations.migrations m
        LEFT OUTER JOIN pgmigrations.scripts d ON d.migration_id = m.id
            AND d.type_id = (
                SELECT id FROM pgmigrations.script_types WHERE name = 'down'
            )
    ORDER BY migration_name
    ;

END $$;

/*
    FUNCTIONS

    pgmigrations.config(
         name  TEXT     -- attribute
        ,value TEXT     -- value
    )

    adds new configuration 'value' for a 'name'

 */

CREATE OR REPLACE FUNCTION
    pgmigrations.config(
         _name  TEXT
        ,_value TEXT
    )
    RETURNS BOOLEAN
AS $$
BEGIN
    LOOP
        -- first try to update the key
        UPDATE pgmigrations.config SET value = _value WHERE name = _name;
        IF found THEN
            RETURN TRUE;
        END IF;
        -- not there, so try to insert the key
        -- if someone else inserts the same key concurrently,
        -- we could get a unique-key failure
        BEGIN
            INSERT INTO pgmigrations.config(name,value)
            VALUES (_name, _value);

            RETURN TRUE;
        EXCEPTION WHEN unique_violation THEN
            -- Do nothing, and loop to try the UPDATE again.
        END;
    END LOOP;
END;
$$  LANGUAGE plpgsql;

/*
    pgmigrations.config(
        name TEXT   -- attribute name
    );

    returns value for the configuration key 'name',
    throws exception if there is no entry in the config table
    for the given 'name'

*/

CREATE OR REPLACE FUNCTION
    pgmigrations.config(
        _attribute TEXT
    )
    RETURNS TEXT
AS $$
DECLARE
    retval TEXT := NULL;
BEGIN
    SELECT value FROM pgmigrations.config WHERE name = _attribute INTO retval;

    IF( retval IS NULL ) THEN
        RAISE EXCEPTION 'Missing configuration for "%"', _attribute;
    END IF;

    RETURN retval;
END;
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

/*
    pgmigrations.is_superuser()
    returns TRUE if current user has SUPERUSER privileges
    or FALSE if it does not
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.is_superuser()
    RETURNS BOOL
AS $$
DECLARE
    is_superuser BOOL := FALSE;
BEGIN
    SELECT usesuper
        FROM  pg_catalog.pg_user
        WHERE usename = current_user
        INTO  is_superuser;

    RETURN is_superuser;
END;
$$  LANGUAGE plpgsql;

/*
    pgmigrations.get_migrations_dir()
    returns a string with a relative path to migrations directory
    specific for current database
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.get_migrations_dir()
    RETURNS TEXT
AS $$
DECLARE
BEGIN

    RETURN pgmigrations.config('basedir')
        || pgmigrations.config('sep_dir')
        || current_database();
END
$$  LANGUAGE plpgsql;

/*
    pgmigrations.validate_script_type(
        script_type TEXT    -- script type name, i.e. 'up'
    );

    returns TRUE if script type is valid,
    throws exception otherwise
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.validate_script_type(
        _script_type_name TEXT
    )
    RETURNS BOOLEAN
AS $$
BEGIN
    IF NOT EXISTS(
        SELECT TRUE FROM pgmigrations.script_types
            WHERE name = _script_type_name
    ) THEN
        RAISE EXCEPTION
            'Invalid script type "%"',
            _script_type_name
        ;
    END IF;

    RETURN TRUE;
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

/*
    pgmigrations.get_migration_script_path(
         migration_dir  TEXT -- i.e. '00'
        ,script_type    TEXT -- i.e. 'up'
    );
    returns TEXT value of the full path to up/down migration script
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.get_migration_script_path(
         _migration_dir TEXT
        ,_script_type   TEXT
    )
    RETURNS TEXT
AS $$
DECLARE
    dir TEXT := NULL;
    sep TEXT := NULL;
    ext TEXT := NULL;
BEGIN

    PERFORM pgmigrations.validate_script_type( _script_type );

    SELECT pgmigrations.config('sep_dir') INTO sep;
    SELECT pgmigrations.config('script_file_extension') INTO ext;
    SELECT pgmigrations.get_migrations_dir() INTO dir;

    RETURN dir
        || sep
        || _migration_dir
        || sep
        || _script_type
        || ext;
END;
$$  LANGUAGE plpgsql;

/*
    pgmigrations.ls_dir(
        dir TEXT    -- relative directory path
    )
    returns a list of files in the directory.
    Must be called with superuser privileges.

    This is essentially a wrapper around PG_LS_DIR,
    to make testing easier, as it could be mocked in
    the test case.

*/

CREATE OR REPLACE FUNCTION
    pgmigrations.ls_dir(
        _dir TEXT
    )
    RETURNS TABLE(
        file TEXT
    )
AS $$
DECLARE
BEGIN
    BEGIN
        RETURN QUERY
            SELECT * FROM PG_LS_DIR( _dir );

            EXCEPTION WHEN others THEN
                RETURN;
    END;
END;
$$  LANGUAGE plpgsql;

/*
    pgmigrations.stat_file(
         filepath TEXT          -- full path to the file
        ,missing_ok BOOLEAN
    )

    Wrapper around PG_STAT_FILE to allow function overrides
    for the unit tests.

*/

CREATE OR REPLACE FUNCTION
    pgmigrations.stat_file(
         _filepath  TEXT
        ,_missing_ok BOOLEAN DEFAULT TRUE
    )
    RETURNS TABLE(
         size           BIGINT
        ,access         TIMESTAMP WITH TIME ZONE
        ,modifications  TIMESTAMP WITH TIME ZONE
        ,change         TIMESTAMP WITH TIME ZONE
        ,creation       TIMESTAMP WITH TIME ZONE
        ,isdir          BOOLEAN
    )
AS $$
BEGIN
    RETURN QUERY
        SELECT * FROM PG_STAT_FILE( _filepath, _missing_ok );
END;
$$  LANGUAGE plpgsql;

/*
    pgmigrations.list_migration_directories()
    returns assorted list of migration directories
    in the path of $pgdata_dir/$config('basedir')/$current_database/
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.list_migration_directories()
    RETURNS TABLE (
        migration_directory TEXT
    )
AS $$
DECLARE
    basedir         TEXT    := NULL;
    file_name       TEXT    := NULL;
    full_path       TEXT    := NULL;
    sep_dir         TEXT    := NULL;

BEGIN
    SELECT pgmigrations.get_migrations_dir() INTO basedir;
    SELECT pgmigrations.config('sep_dir') INTO sep_dir;

    DROP TABLE IF EXISTS _pgmigrations_migration_directories;

    CREATE TEMPORARY TABLE _pgmigrations_migration_directories(
        migration_directory TEXT PRIMARY KEY NOT NULL
    ) ON COMMIT DROP;

    -- loop over each file in the $config('basedir') directory
    FOREACH file_name IN ARRAY ARRAY(
        SELECT pgmigrations.ls_dir(basedir)
    ) LOOP
        full_path = basedir || sep_dir || file_name;

        -- ignore non directory files
        CONTINUE WHEN NOT(
            SELECT (pgmigrations.stat_file( full_path )).isdir
        );
        -- add file to the temporary table
        INSERT INTO _pgmigrations_migration_directories( migration_directory )
            VALUES( file_name );

    END LOOP;

    RETURN QUERY
        SELECT t.migration_directory
        FROM _pgmigrations_migration_directories t;
END;
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

/*
    pgmigrations.read_file( filepath TEXT )
    returns file content of the $filepath,
    requires superuser privileges
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.read_file(
        _filepath TEXT
    )
    RETURNS TEXT
AS $$
DECLARE
    content TEXT := NULL;
BEGIN
    -- throw exception if called as non superuser
    IF( pgmigrations.is_superuser() != TRUE) THEN
        RAISE EXCEPTION 'must be superuser to call read_file()';
    END IF;

    -- return content of the non empty, non directory file
    IF(
        SELECT TRUE
        FROM pgmigrations.stat_file(_filepath, TRUE)
        WHERE size > 0 AND NOT isdir
    ) THEN
        SELECT pg_read_file(_filepath) INTO content;
    END IF;

    RETURN content;
END
$$  LANGUAGE plpgsql;

/*
    pgmigrations.add_migration(
         migration_name  TEXT   -- unique migration name
        ,up_script       TEXT   -- required upgrade script
        ,down_script     TEXT   -- optional downgrade script
    )
    RETURNS TRUE

    creates new migration with up and down scripts, should not
    be used directly, but only via pgmigrations.load_migrations()

    TODO: refactor to be able to cope with undefined number of script types
    (i.e. not only up/down - this should be derived from script_type table )
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.add_migration(
         _migration_name    TEXT
        ,_up                TEXT
        ,_down              TEXT DEFAULT NULL
    )
    RETURNS BOOLEAN
AS $$
DECLARE
    migration_id INTEGER := NULL;
BEGIN
    INSERT INTO
        pgmigrations.migrations(
            name
        )
        SELECT _migration_name
            WHERE NOT EXISTS (
                SELECT id
                    FROM pgmigrations.migrations
                    WHERE name = _migration_name
            )
    RETURNING id INTO migration_id;

    -- migration already exists
    IF( migration_id IS NULL ) THEN
        RAISE NOTICE 'migration "%" already exists'
            , _migration_name
        ;
        RETURN FALSE;
    END IF;

    -- create up script
    INSERT INTO
        pgmigrations.scripts (
             migration_id
            ,type_id
            ,script
        )
        VALUES (
             migration_id
            ,( SELECT id FROM pgmigrations.script_types WHERE name = 'up' )
            ,_up
        )
    ;

    -- create down script
    IF( _down IS NULL) THEN
        RETURN TRUE;
    END IF;

    INSERT INTO
        pgmigrations.scripts (
             migration_id
            ,type_id
            ,script
        )
        VALUES (
             migration_id
            ,( SELECT id FROM pgmigrations.script_types WHERE name = 'down' )
            ,_down
        )
    ;

    RETURN TRUE;
END
$$  LANGUAGE plpgsql;

/*
    pgmigrations.load_migrations();

    uploads migration scripts from filesystem to
    pgmigrations.migrations table

    TODO: refactor to get rid of hardcoded 'up'/'down' script values
    TODO: add force override flag, so that migration could be overwriten
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.load_migrations()
    RETURNS BOOLEAN
AS $$
DECLARE
    basedir         TEXT;
    down_script     TEXT;
    dir_list_rec    RECORD;
    dir_sep         TEXT;
    ext             TEXT;
    filepath        TEXT;
    up_script       TEXT;
BEGIN

    SELECT pgmigrations.config('sep_dir') INTO dir_sep;
    SELECT pgmigrations.get_migrations_dir() INTO basedir;
    SELECT pgmigrations.config('script_file_extension') INTO ext;

    -- loop over migration directories ('00','01' etc )
    FOR dir_list_rec IN
        SELECT migration_directory
            FROM pgmigrations.list_migration_directories()
            ORDER BY migration_directory ASC
    LOOP

        -- continue to the next directory, if migration exists already
        IF EXISTS(
            SELECT migration
                FROM pgmigrations.migrations_info
                WHERE migration = dir_list_rec.migration_directory
        ) THEN
            RAISE NOTICE 'Migration "%" already loaded'
                ,dir_list_rec.migration_directory;

            CONTINUE;
        END IF;

        -- read up/down scripts
        up_script   = NULL;
        down_script = NULL;

        filepath = basedir
            || dir_sep
            || dir_list_rec.migration_directory
            || dir_sep
            || 'up'
            || ext;

        -- "up" script must exist, skip migration if it does not
        SELECT pgmigrations.read_file( filepath ) INTO up_script;

        IF( up_script IS NULL ) THEN
            RAISE NOTICE
                 'No "up%" script found, skipping migration "%"'
                ,ext
                ,dir_list_rec.migration_directory;

            CONTINUE;
        END IF;

        filepath = basedir
            || dir_sep
            || dir_list_rec.migration_directory
            || dir_sep
            || 'down'
            || ext;

        -- "down" script can be NULL
        SELECT pgmigrations.read_file( filepath ) INTO down_script;

        -- finally add migration
        PERFORM pgmigrations.add_migration(
             dir_list_rec.migration_directory
            ,up_script
            ,down_script
        );

    END LOOP;

    RETURN TRUE;
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

/*
    pgmigrations.add_script_log_record(
         script_id  INTEGER             -- pgmigrations.script row id
        ,success    BOOLEAN             -- script execution result
        ,error      TEXT DEFAULT NULL   -- optional error message
    )
    returns TRUE on success, or throws exception
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.add_script_log_record(
         _script_id  INTEGER
        ,_success    BOOLEAN
        ,_error      TEXT DEFAULT NULL
    )
    RETURNS BOOLEAN
AS $$
BEGIN
    INSERT INTO pgmigrations.script_log(
         script_id
        ,success
        ,error
    )
    VALUES
    (
         _script_id
        ,_success
        ,_error
    )
    ;

    RETURN TRUE;
END
$$  LANGUAGE plpgsql
    SECURITY DEFINER;

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
    success         BOOLEAN;
    error_message   TEXT;
BEGIN
    -- loop through not applied migrations and execute them
    FOR migration_rec IN
        SELECT
             migration_name
            ,migration_id
            ,up_script
            ,up_script_id
        FROM pgmigrations.pending_upgrades
    LOOP

        error_message = NULL;
        success       = NULL;

        BEGIN
            EXECUTE migration_rec.up_script;
            success = TRUE;

            EXCEPTION WHEN others THEN
                error_message   = SQLERRM;
                success         = FALSE;
        END;

        -- update script log
        PERFORM pgmigrations.add_script_log_record(
             migration_rec.up_script_id
            ,success
            ,error_message
        );

    END LOOP;
    RETURN TRUE;
END
$$  LANGUAGE plpgsql;

/*
    pgmigrations.rollback_migration(
        migration TEXT  -- migration name
    )
    RETURNS TRUE on success, false on error
    Creates a log entry.

    TODO: refactor, as its copy paste from pgmigrations.apply_migrations
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.rollback_migration(
        _migration TEXT
    )
    RETURNS BOOLEAN
AS $$
DECLARE
    success         BOOLEAN;
    migration_rec   RECORD;
    error_message   TEXT;
BEGIN
    FOR migration_rec IN
        SELECT
             migration_name
            ,migration_id
            ,downgrade_script
            ,downgrade_script_id
        FROM pgmigrations.downgrade_scripts
        WHERE migration_name = _migration
        LIMIT 1
    LOOP

        error_message = NULL;
        success       = NULL;

        BEGIN
            EXECUTE migration_rec.downgrade_script;
            success = TRUE;

            EXCEPTION WHEN others THEN
                error_message   = SQLERRM;
                success         = FALSE;
        END;

        -- update script log
        PERFORM pgmigrations.add_script_log_record(
             migration_rec.downgrade_script_id
            ,success
            ,error_message
        );

    END LOOP;
    RETURN success;
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
    EXECUTE 'GRANT SELECT ON pgmigrations.downgrade_scripts TO ' || _role;

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
    EXECUTE 'REVOKE ALL PRIVILEGES ON pgmigrations.downgrade_scripts FROM ' || _role;
    EXECUTE 'REVOKE ALL PRIVILEGES ON SCHEMA pgmigrations FROM '            || _role;

    RETURN TRUE;
END
$$  LANGUAGE plpgsql;

/*
/
    pgmigrations.upgrade()

    loads migrations from the file system and applies them
*/

CREATE OR REPLACE FUNCTION
    pgmigrations.upgrade()
    RETURNS TABLE (
         migration      TEXT
        ,up             TEXT
        ,up_run         TIMESTAMP WITH TIME ZONE
        ,up_success     BOOLEAN
        ,up_error       TEXT
        ,down           TEXT
        ,down_run       TIMESTAMP WITH TIME ZONE
        ,down_success   BOOLEAN
        ,down_error     TEXT
    )
AS $$
BEGIN
    PERFORM pgmigrations.load_migrations();
    PERFORM pgmigrations.apply_migrations();

    RETURN QUERY
        SELECT
             i.migration
            ,i.up
            ,i.up_run
            ,i.up_success
            ,i.up_error
            ,i.down
            ,i.down_run
            ,i.down_success
            ,i.down_error
        FROM pgmigrations.migrations_info i
        ORDER BY i.migration ASC;

    RETURN;
END
$$  LANGUAGE plpgsql;
