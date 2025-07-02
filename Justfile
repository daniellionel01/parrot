
default:
  @just --choose

clean:
  find . -name build -type d -prune -o -name gleam.toml -execdir gleam clean \;

# count lines of code of (excluding tests)
@loc:
  echo "SOURCE CODE"
  cloc . --vcs=git --exclude-dir=integration,test
  echo "\TESTS"
  cloc integration test --vcs=git

@integration:
  just test-sqlite
  just test-mysql
  just test-psql

@test-mysql:
  just integration/mysql/test

@test-psql:
  just integration/psql/test

@test-sqlite:
  just integration/sqlite/test
