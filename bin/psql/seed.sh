#!/bin/bash

psql -h 127.0.0.1 -p 5432 -U daniel -d parrot -f ./bin/psql/seed.sql
