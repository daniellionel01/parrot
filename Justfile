
default:
  @just --choose

@integration_test:
  just test-sqlite
  just test-mysql
  just test-psql

@test-mysql:
  just integration_test/mysql/test

@test-psql:
  just integration_test/psql/test

@test-sqlite:
  gleam run -m parrot gen sqlite file.db
