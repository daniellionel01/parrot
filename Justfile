
default:
  @just --choose

@integration_test:
  just test-sqlite
  just test-mysql
  just test-psql

[working-directory: "integration_test/mysql"]
@test-mysql:
  gleam run -m parrot gen mysql "mysql://root:daniel@127.0.0.1:3309/parrot"

[working-directory: "integration_test/psql"]
@test-psql:
  gleam run -m parrot gen psql "postgresql://daniel:parrot@127.0.0.1:5432/parrot"

[working-directory: "integration_test/sqlite"]
@test-sqlite:
  gleam run -m parrot gen sqlite file.db
