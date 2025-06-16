
default:
  @just --choose

@integration-test:
  just test-sqlite
  just test-mysql
  just test-psql

@test-mysql:
  just integration_test/mysql/test

@test-psql:
  just integration_test/psql/test

@test-sqlite:
  just integration_test/sqlite/test
