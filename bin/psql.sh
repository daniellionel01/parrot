#!/bin/bash

# postgresql://daniel:parrot@127.0.0.1:5432/parrot
docker run \
  --rm -d \
  --name parrot-psql \
  -e POSTGRES_USER=daniel \
  -e POSTGRES_PASSWORD=parrot \
  -e POSTGRES_DB=parrot \
  -e PGDATA=/var/lib/postgresql/data/pgdata \
  -p 5432:5432 \
  -v /var/lib/db-parrot:/var/lib/postgresql/data/pgdata \
  postgres:17
