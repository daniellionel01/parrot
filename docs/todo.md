# todo

- [x] add decoders for all query result types (toggle in config)
- [x] how do we handle datetime? Int? String? Extra Library?
- [x] fix decoder to be based on tuples

- [x] return param wrapped list instead of tuple

- [ ] only import timestamp if necessary
- [ ] fix parrot version (not accurate taking local gleam.toml)

- [ ] handle "any" sqlc type
  - [ ] suggest user to cast type
  - [ ] second pass with example data to infer type

- [ ] types
  - [ ] https://github.com/sqlc-dev/sqlc-gen-python/blob/main/internal/postgresql_type.go
  - [ ] https://github.com/sqlc-dev/sqlc-gen-kotlin/blob/main/internal/core/mysql_type.go
  - [ ] https://github.com/sqlc-dev/sqlc-gen-kotlin/blob/main/internal/core/postgresql_type.go

- [ ] additional config
  - [ ] custom data types and custom functions based on schema
  - [ ] custom functions
  - [ ] custom imports
  - [ ] footer code
  - [ ] for gmysql
  - [ ] explain in readme

- [ ] add examples for drivers
  - [ ] mysql: https://github.com/VioletBuse/gmysql
  - [ ] postgresql: https://github.com/lpil/pog
  - [ ] sqlite: https://github.com/lpil/sqlight
  - [ ] link in readme

- [ ] catch error when running codegen
  - [ ] missing dependency: gleam_time

- [ ] test more advanced queries, schemas & sqlc features
  - [ ] https://docs.sqlc.dev/en/latest/howto/named_parameters.html
  - [ ] sql functions such as datetime (sqlite) or strf

- [ ] integration tests
  - [ ] sqlite
  - [ ] mysql
  - [ ] postgresql

- [ ] create schema from existing database?
  - [ ] pg_dump (https://github.com/sqlc-dev/sqlc/discussions/1551#discussioncomment-2677299)
  - [ ] mysqldump (https://dev.mysql.com/doc/refman/8.4/en/mysqldump.html)
  - [ ] sqlite (https://www.geeksforgeeks.org/how-to-export-database-and-table-schemas-in-sqlite/)

- [ ] map all types to gleam
- [ ] config: error instead of dynamic type for unknown columns

- [ ] remove "sqlc generate" step by executing it in gleam
- [ ] remove need for sqlc all together by creating the sqlc.yaml on demand and add emitting option in config
- [ ] dynamically download sqlc (https://docs.sqlc.dev/en/stable/overview/install.html)

- [ ] consider using https://jsontypedef.com/ ?

- [ ] catalog -> schemas -> enums
- [ ] catalog -> schemas -> composite_types
- [ ] catalog -> schemas -> tables -> columns -> embed_table

- [ ] reuse types if they have the same schema (f.e. select *)

- [ ] auto discover sqlc.yaml/json
  - [ ] how do we handle multiple?
  - [ ] we could do all of them?
    - [ ] one module for each sqlc.yaml/json
    - [ ] name -> parent directory of sqlc config? or from catalog schema name?

- [ ] add "auto generated" comments in head of files similar to...
  - ... https://github.com/sqlc-dev/sqlc/blob/main/examples/batch/postgresql/query.sql.go

- [ ] support javascript target

- [ ] add example repositories

- [ ] use llm to generate various complicated queries that are automatically run and tested

- [ ] more advanced handling of joins

- [ ] think about usage in larger codebases and scaling
