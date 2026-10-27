default:
    @just --choose

clean:
    gleam clean

choire:
    gleam run -m choire

update:
    gleam update

# count lines of code of (excluding tests)
@loc:
    echo "SOURCE CODE"
    cloc . --vcs=git --exclude-dir=test
    echo "\TESTS"
    cloc test --vcs=git

compose := `command -v podman >/dev/null && echo "podman compose" || echo "docker compose"`

# start the databases used by the integration tests (see compose.yaml)
db-up:
    {{compose}} up -d --wait

db-down:
    {{compose}} down

# needs `just db-up`, `sqlite3`, `psql`, `pg_dump`, `mysql` and `mysqldump`
test-integration:
    PARROT_TEST_POSTGRES_URL="postgresql://parrot:parrot@127.0.0.1:55432/parrot" \
    PARROT_TEST_MYSQL_URL="mysql://root:parrot@127.0.0.1:33306/parrot" \
    gleam test integration
