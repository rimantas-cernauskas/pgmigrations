FROM postgres:10
RUN apt-get update
RUN apt-get install --assume-yes apt-utils
RUN apt-get --assume-yes install git patch make postgresql-server-dev-$PG_MAJOR libtap-parser-sourcehandler-pgtap-perl
ENV PGUSER=postgres
RUN git clone https://github.com/theory/pgtap.git /pgtap && chmod a+rw /pgtap
WORKDIR /pgtap
RUN git checkout && make && make install
