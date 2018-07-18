-- Mock functions for list_migration_directories test

SET ROLE __pgmigrations_superuser;

CREATE TEMPORARY TABLE _mock_ls_dir(
    dir TEXT PRIMARY KEY
) ON COMMIT DROP;
GRANT ALL PRIVILEGES ON _mock_ls_dir TO __pgmigrations_testuser;

-- set default values
INSERT INTO _mock_ls_dir(
    dir
) VALUES (
    '00'
),(
    '01'
),(
    '02'
);

-- define mocked function get_migrations_dir
CREATE OR REPLACE FUNCTION
    pgmigrations.get_migrations_dir()
    RETURNS TEXT
AS $$
BEGIN
    RETURN 'my_awesome_database';
END;
$$  LANGUAGE plpgsql;

-- define mocked function ls_dir
CREATE OR REPLACE FUNCTION
    pgmigrations.ls_dir(
         _dir TEXT
    )
    RETURNS TABLE(dir TEXT)
AS $$
BEGIN
    RETURN QUERY
        SELECT * FROM _mock_ls_dir;
END;
$$ LANGUAGE plpgsql;

-- define mocked function stat_file
CREATE OR REPLACE FUNCTION
    pgmigrations.stat_file(
         _filepath   TEXT
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
        SELECT * FROM (
            VALUES(
                 4096::BIGINT
                ,NOW()
                ,NOW()
                ,NOW()
                ,NULL::TIMESTAMP WITH TIME ZONE
                ,TRUE
            )
        ) AS t(
             size
            ,access
            ,modifications
            ,change
            ,creation
            ,isdir
        );
END;
$$  LANGUAGE plpgsql;