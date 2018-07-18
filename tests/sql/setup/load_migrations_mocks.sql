-- Mock functions for load_migrations test

SET ROLE __pgmigrations_superuser;

CREATE TEMPORARY TABLE _mock_migrations(
     dir    TEXT PRIMARY KEY
    ,up     TEXT
    ,down   TEXT
) ON COMMIT DROP;
GRANT ALL PRIVILEGES ON _mock_migrations TO __pgmigrations_testuser;

-- set default values
INSERT INTO _mock_migrations(
     dir
    ,up
    ,down
) VALUES (
    '00'
    ,'CREATE TABLE foo( id SERIAL PRIMARY KEY );'
    ,'DROP TABLE foo;'
),(
     '01'
    ,NULL
    ,'CREATE TABLE bar( id SERIAL PRIMARY KEY );'
),(
     '02'
    ,'ALTER TABLE foo ADD COLUMN new_column TEXT NOT NULL;'
    ,NULL
);

-- define mocked function list_migration_directories
CREATE OR REPLACE FUNCTION
    pgmigrations.list_migration_directories()
    RETURNS TABLE (
        migration_directory TEXT
    )
AS $$
BEGIN
    RETURN QUERY
        SELECT dir AS migration_directory
        FROM _mock_migrations;
END;
$$  LANGUAGE plpgsql;

-- define mocked function read_file
CREATE OR REPLACE FUNCTION
    pgmigrations.read_file(
        _filepath    TEXT
    )
    RETURNS TEXT
AS $$
DECLARE
    migration   TEXT := NULL;
    content     TEXT := NULL;
    type        TEXT := NULL;
    parts       TEXT[];
BEGIN

    SELECT regexp_matches(_filepath, '/(\d+)/(up|down)\.sql')
        INTO parts;

    migration = parts[1];
    type      = parts[2];

    IF( type = 'up')
    THEN
        SELECT up FROM _mock_migrations WHERE dir = migration INTO content;
    ELSE
        SELECT down FROM _mock_migrations WHERE dir = migration INTO content;
    END IF;

    RETURN content;
END
$$  LANGUAGE plpgsql;