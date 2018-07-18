-- Test function pgmigrations.validate_script_type()
\i tests/sql/setup/init.sql
BEGIN;
SELECT plan(2);

SET ROLE __pgmigrations_testuser;
SELECT is (
    pgmigrations.validate_script_type( 'up' ),
    TRUE,
    'validate_script_type() should return TRUE when called with existing script type'
);

PREPARE my_query AS
    SELECT pgmigrations.validate_script_type( $1 );

select throws_ok(
    'EXECUTE my_query( ''should not exist'' )',
    'Invalid script type "should not exist"',
    'should throw exception when called with non exitent script type'
);
DEALLOCATE my_query;

SELECT * FROM finish();

ROLLBACK;