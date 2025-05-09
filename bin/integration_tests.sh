#!/bin/bash
sqlc generate --file integration_tests/mysql/sqlc.yaml
sqlc generate --file integration_tests/psql/sqlc.yaml
sqlc generate --file integration_tests/sqlite/sqlc.yaml
