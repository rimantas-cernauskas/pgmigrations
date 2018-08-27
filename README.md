# Postgres Database Migrations [![Build Status](https://travis-ci.org/rimantas-cernauskas/pgmigrations.svg?branch=master)](https://travis-ci.org/rimantas-cernauskas/pgmigrations)
___
Collection of the plpgsql functions to manage database migrations for [PostgreSQL](https://www.postgresql.org/) databases.

### Dependencies
pgmigrations where created for postgreSQL version 10, and while it potentially would work, no previous versions have been tested.
Currently project is written in plpgsql language with no runtime dependencies, however [pgTAP](https://github.com/theory/pgtap) is required to run unit tests manually or via `make installcheck`.

### Installation
* on a running postgreSQL server, checkout git repository or copy source code
* change working directory to pgmigrations source
* run `make install`
* optionally run `make installcheck` ( requires [pgTAP](https://github.com/theory/pgtap) installation )
* run `psql YOUR_AWESOME_DATABASE -c "CREATE EXTENSION pgmigrations"`
* grant required privileges to role for using migration functions: `psql YOUR_AWESOME_DATABASE -c "SELECT pgmigrations.grant_privileges( 'DATABASE_USER_ROLE' );"`

### Usage

* Create migrations directory for your database in $PGDATA dir: `mkdir -p $PGDATA\migrations\MY_AWESOME_DATABASE`
* Create migration script directories and upgrade/donwgrade scripts. Migration is defined by directory name and is applied in an alphabetical order, so choose some reasonable naming convention, like 000,001,002,003 etc. Migration scripts must be named `up.sql` for upgrade script and `down.sql` for downgrade (upgrade script is required, while downgrade is optional)
  * `mkdir $PGDATA\migrations\MY_AWESOME_DATABASE\000`
  * `echo "CREATE TABLE FOO(id SERIAL);" > $PGATA\migrations\MY_AWESOME_DATABASE\000\up.sql`
  * `echo "DROP TABLE FOO;" > $PGDATA\migrations\MY_AWESOME_DATABASE\000\down.sql`
* Apply migrations by calling `pgmigrations.upgrade()` function:
  * `psql MY_AWESOME_DATABASE -c "SELECT pgmigrations.upgrade();"
* (Optional) Check migration status by inspecting results of `pgmigrations.migrations_info` view:
  * `psql MY_AWESOME_DATABASE -c "SELECT * FROM pgmigrations.migrations_info;`
* Migrations can be rolled back one at a time only. In the event when rollback is required, call `pgmigrations.rollback_migration('XXXX')`, where XXXX is migration name:
  * `psql MY_AWESOME_DATABASE -c "SELECT pgmigrations.rollback_migration('000');`


### [License](https://github.com/rimantas-cernauskas/pgmigrations/blob/master/LICENSE)
