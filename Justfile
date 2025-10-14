
find-unused:
  #!/bin/bash
  dependencies=$(awk '/^\[dependencies\]/{flag=1;next}/^\[/{flag=0}flag' gleam.toml | grep -E '^[a-z_]+ =' | cut -d' ' -f1)
  unused=()
  for dep in $dependencies; do
    if [[ $dep == gleam_* ]]; then
      # gleam_stdlib -> gleam/
      # gleam_json -> gleam/json
      import_pattern="gleam/"
      if [ "$dep" != "gleam_stdlib" ]; then
          suffix="${dep#gleam_}"
          import_pattern="gleam/$suffix"
      fi
    else
        import_pattern="$dep"
    fi

    if ! grep -rq "import $import_pattern" src/ --include="*.gleam" 2>/dev/null; then
        unused+=("$dep")
    fi
  done
  echo $unused

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
