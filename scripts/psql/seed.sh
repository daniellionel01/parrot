#!/bin/bash

psql -h 127.0.0.1 -p 5433 -U postgres -d jsontypedef -f ./scripts/psql/seed.sql
