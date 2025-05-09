#!/bin/bash
([[ $OSTYPE = "msys" ]] || [[ $OSTYPE = "cygwin" ]]) && DIR=$(pwd) || DIR=/var/lib/postgresql/data

# postgres://postgres:daniel@127.0.0.1:5433/jsontypedef
docker run \
  --rm --name postgres-jsontypedef -d \
  -e="POSTGRES_PASSWORD=daniel" \
  -e="POSTGRES_DB=jsontypedef" \
  -p 5433:5432 \
  -v=$DIR:/var/lib/postgresql/data \
  postgres:15 \
  -c 'max_connections=10000'
