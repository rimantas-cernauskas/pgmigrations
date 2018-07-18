-- Test function pgmigrations.stat_file()
\i tests/sql/setup/init.sql

/*

This test is relying on the existece of PG_VERSION file

*/

BEGIN;
SELECT plan(2);

PREPARE my_query AS
    SELECT * FROM pgmigrations.stat_file( $1 );

PREPARE my_expect AS
    SELECT * FROM PG_STAT_FILE( $1 );

SELECT results_eq(
     'EXECUTE my_query(''./'')'
    ,'EXECUTE my_expect(''./'')'
    ,'should return same result as PG_STAT_FILE for a directory'
);

SELECT results_eq(
     'EXECUTE my_query(''PG_VERSION'')'
    ,'EXECUTE my_expect(''PG_VERSION'')'
    ,'should return same result as PG_STAT_FILE for a file'
);

DEALLOCATE my_query;
DEALLOCATE my_expect;

SELECT * FROM finish();
ROLLBACK;