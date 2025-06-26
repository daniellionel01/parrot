
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

@docker:
  docker build . --file Dockerfile --tag parrot
  docker run -d --rm parrot

@docker-test:
  docker build . --file Dockerfile --tag parrot-test
  docker run --rm parrot-test /app/entrypoint.sh test

@docker-compose-test:
  docker-compose up --build --abort-on-container-exit
