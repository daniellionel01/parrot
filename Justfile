
[working-directory: "integration_tests/mysql"]
integration_test_mysql:
  gleam run -m parrot gen mysql "mysql://root:daniel@127.0.0.1:3309/parrot"

[working-directory: "integration_tests/psql"]
integration_test_psql:
  gleam run -m parrot gen psql "postgresql://daniel:parrot@127.0.0.1:5432/parrot"

[working-directory: "integration_tests/sqlite"]
integration_test_sqlite:
  gleam run -m parrot gen sqlite file.db
