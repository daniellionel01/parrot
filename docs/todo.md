# todo

## road to v1

- [x] `-e` to override environment variable name

- [ ] add premade driver utilities
  - [ ] sqlight
  - [ ] pog

- [ ] any as error?
  - [ ] provide decoder as fallback

- [ ] timestamps as ints?
  - [ ] determine precision from database (sec, msec, nsec, ...)

- [ ] named sqlc parameters

- [ ] fully automated integration test suites
  - [ ] sqlite
  - [ ] mysql
  - [ ] psql

- [ ] errors
  - [ ] catch error when queries.json is not generated (as in `sqlc generate` fails)

- [ ] road to v1
  - [ ] warning when sqlc is not installed (link installation page)
  - [ ] auto determine type of db (look for DATABASE_URL or .db, .sqlite files)

- [ ] handle "any" sqlc type
  - [ ] suggest user to cast type
  - [ ] second pass with example data to infer type

- [ ] extend types
  - [ ] https://github.com/sqlc-dev/sqlc-gen-python/blob/main/internal/postgresql_type.go
  - [ ] https://github.com/sqlc-dev/sqlc-gen-kotlin/blob/main/internal/core/mysql_type.go
  - [ ] https://github.com/sqlc-dev/sqlc-gen-kotlin/blob/main/internal/core/postgresql_type.go

- [ ] add examples for drivers
  - [ ] mysql: https://github.com/VioletBuse/gmysql
  - [ ] postgresql: https://github.com/lpil/pog
  - [ ] sqlite: https://github.com/lpil/sqlight
  - [ ] link in readme
