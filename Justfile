
default:
  @just --choose

clean:
  find . -name build -type d -prune -o -name gleam.toml -execdir gleam clean \;

# count lines of code of (excluding tests)
@loc:
  echo "SOURCE CODE"
  cloc . --vcs=git --exclude-dir=integration_test,test
  echo "\TESTS"
  cloc integration_test test --vcs=git

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
