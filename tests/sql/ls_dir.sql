-- Test function pgmigrations.ls_dir()
\i tests/sql/setup/init.sql

BEGIN;
SELECT plan(1);

PREPARE my_query AS
    SELECT * FROM pgmigrations.ls_dir( $1 );

PREPARE my_expect AS
    SELECT * FROM PG_LS_DIR( $1 );

SELECT results_eq(
     'EXECUTE my_query(''./'')'
    ,'EXECUTE my_expect(''./'')'
    ,'should return same files as PG_LS_DIR (defaults)'
);

DEALLOCATE my_query;
DEALLOCATE my_expect;

SELECT * FROM finish();
ROLLBACK;