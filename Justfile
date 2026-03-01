default:
    @just --choose

clean:
    find . -name build -type d -prune -o -name gleam.toml -execdir gleam clean \;

choire:
    gleam run -m choire

update:
    gleam update
    find . -name build -type d -prune -o -name gleam.toml -execdir gleam update \;

# count lines of code of (excluding tests)
@loc:
    echo "SOURCE CODE"
    cloc . --vcs=git --exclude-dir=integration,test
    echo "\TESTS"
    cloc integration test --vcs=git

@integration:
    just integration/sqlite/test
    just integration/sqlite-no-optional/test
    just integration/mysql/test
    just integration/psql/test
