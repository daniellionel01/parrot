#!/bin/bash
sqlc generate --file sql/mysql/sqlc.yaml
sqlc generate --file sql/psql/sqlc.yaml
sqlc generate --file sql/sqlite/sqlc.yaml
