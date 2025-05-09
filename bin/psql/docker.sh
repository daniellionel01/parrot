#!/bin/bash
([[ $OSTYPE = "msys" ]] || [[ $OSTYPE = "cygwin" ]]) && DIR=$(pwd) || DIR=/var/lib/postgresql/data

# postgresql://daniel:parrot@127.0.0.1:5432/parrot
docker run -d \
  --name parrot-db \
  -e POSTGRES_USER=daniel \
  -e POSTGRES_PASSWORD=parrot \
  -e POSTGRES_DB=parrot \
  -e PGDATA=/var/lib/postgresql/data/pgdata \
  -p 5432:5432 \
  -v ./data:/var/lib/postgresql/data/pgdata \
  postgres:17
