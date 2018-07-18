#!/bin/bash
TRIES=10;
FILE=/var/run/postgresql/.s.PGSQL.5432;

while [ $TRIES -gt 0 ] && [ ! -S "$FILE" ]
do
    echo "============== Waiting for database"
    sleep 1;
    TRIES=$(($TRIES-1));
done

echo "============== Creating and testing PGTAP extension   =============="
cd /pgtap && make installcheck && psql -c "CREATE EXTENSION pgtap"
cd /pgtap/sql && psql -d template1 -f pgtap.sql

echo "============== Creating and testing PGMIGRATIONS extension ========="
cd /pgmigrations && make install && make installcheck
