EXTENSION = pgmigrations
TESTS     = $(wildcard tests/sql/*.sql)
DATA      = $(wildcard *--*.sql)

REGRESS_OPTS  = --inputdir=tests              \
                --load-extension=pgmigrations \
                --load-language=plpgsql		  \
                --outputdir=tests

REGRESS = setup/startup $(patsubst tests/sql/%.sql,%,$(TESTS)) setup/shutdown


PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
