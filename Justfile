
default:
  @just --choose

@integration_test:
  just test-sqlite
  just test-mysql
  just test-psql

@test-mysql:
  just integration_test/mysql/test

@test-psql:
  gleam run -m parrot gen psql "postgresql://daniel:parrot@127.0.0.1:5432/parrot"

@test-sqlite:
  gleam run -m parrot gen sqlite file.db
