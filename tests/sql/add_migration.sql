-- Test function pgmigrations.add_migration
\i tests/sql/setup/init.sql
BEGIN;
SELECT plan(5);

-- add_migration() cannot be called as a non superuser
SET ROLE __pgmigrations_testuser;

PREPARE my_query AS
    SELECT * FROM pgmigrations.add_migration(
         '00'              -- migration name
        ,'up script 00'    -- up script
        ,'down script 00'  -- down script
    );

SELECT throws_ilike(
     'my_query'
    ,'%permission denied%'
    ,'should throw error when called without superuser privileges'
);

DEALLOCATE my_query;

-- add_migration() can be called as a superuser
SET ROLE __pgmigrations_superuser;

SELECT is(
    pgmigrations.add_migration(
         '00'              -- migration name
        ,'up script 00'    -- up script
        ,'down script 00'  -- down script
    )
    ,TRUE
    ,'add_migration() should return TRUE when migration is created'
);

-- check that migration has actually been created
PREPARE my_query AS
    SELECT migration, up, down
        FROM pgmigrations.migrations_info
        WHERE migration = '00';

PREPARE my_expect AS
    SELECT * FROM (
        VALUES
        (
             '00'
            ,'up script 00'
            ,'down script 00'
        )
    )
    t(
         migration
        ,up
        ,down
    );

SELECT results_eq(
     'my_query'
    ,'my_expect'
    ,'should have expected migration created'
);

DEALLOCATE my_query;
DEALLOCATE my_expect;

-- test what happends when existing migration( same migration name ) attempted to be created
SELECT is(
    pgmigrations.add_migration(
         '00'
        ,'up script 00'
        ,'down script 00'
    )
    ,FALSE
    ,'add_migration() should return FALSE when adding already existing migration'
);

-- test add_migration with only 'up' script
SELECT is(
    pgmigrations.add_migration(
         '01'
        ,'up script 01'
    )
    ,TRUE
    ,'add_migration() should return TRUE when adding with "up" script only'
);

SELECT * FROM finish();
ROLLBACK;