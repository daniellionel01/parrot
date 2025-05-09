# todo

- [x] add decoders for all query result types (toggle in config)
- [x] how do we handle datetime? Int? String? Extra Library?
- [x] fix decoder to be based on tuples

- [x] return param wrapped list instead of tuple

- [x] bug fix: joins

- [ ] only import timestamp if necessary

- [ ] remove config -> just use defaults
  - [x] put .parrot directory in build directory (similar to lustre)
  - [x] use all *.sql files (similar to squirrel)
  - [x] auto fetch schema
  - [x] auto create sqlc config
  - [ ] warning when sqlc is not installed (link installation page)
  - [ ] auto determine type of db (look for DATABASE_URL or .db, .sqlite files)

- [ ] handle "any" sqlc type
  - [ ] suggest user to cast type
  - [ ] second pass with example data to infer type

- [ ] types
  - [ ] https://github.com/sqlc-dev/sqlc-gen-python/blob/main/internal/postgresql_type.go
  - [ ] https://github.com/sqlc-dev/sqlc-gen-kotlin/blob/main/internal/core/mysql_type.go
  - [ ] https://github.com/sqlc-dev/sqlc-gen-kotlin/blob/main/internal/core/postgresql_type.go

- [ ] add examples for drivers
  - [ ] mysql: https://github.com/VioletBuse/gmysql
  - [ ] postgresql: https://github.com/lpil/pog
  - [ ] sqlite: https://github.com/lpil/sqlight
  - [ ] link in readme

- [ ] test more advanced queries, schemas & sqlc features
  - [ ] https://docs.sqlc.dev/en/latest/howto/named_parameters.html
  - [ ] sql functions such as datetime (sqlite) or strf

- [ ] automated integration tests
  - [ ] sqlite
  - [ ] mysql
  - [ ] postgresql

- [x] create schema from existing database?
  - [x] pg_dump (https://github.com/sqlc-dev/sqlc/discussions/1551#discussioncomment-2677299)
  - [x] mysqldump (https://dev.mysql.com/doc/refman/8.4/en/mysqldump.html)
  - [x] sqlite (https://www.geeksforgeeks.org/how-to-export-database-and-table-schemas-in-sqlite/)

- [ ] map all types to gleam
- [ ] config: error instead of dynamic type for unknown columns

- [x] remove "sqlc generate" step by executing it in gleam
- [x] remove need for sqlc all together by creating the sqlc.yaml on demand and add emitting option in config
- [ ] dynamically download sqlc (https://docs.sqlc.dev/en/stable/overview/install.html)
  - [ ] copy from https://github.com/lustre-labs/lustre esbuild binary

- [ ] catalog -> schemas -> enums
- [ ] catalog -> schemas -> composite_types
- [ ] catalog -> schemas -> tables -> columns -> embed_table

- [ ] add example repositories
  - [ ] postgresql
  - [ ] sqlite
  - [ ] mysql

- [ ] use llm to generate various complicated queries that are automatically run and tested

- [ ] think about usage in larger codebases and scaling
