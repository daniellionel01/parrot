# todo

- [ ] how do we handle datetime? Int? String? Extra Library?

- [ ] consider using https://jsontypedef.com/ ?

- [ ] catalog -> schemas -> enums
- [ ] catalog -> schemas -> composite_types
- [ ] catalog -> schemas -> tables -> columns -> embed_table

- [ ] add supported drivers
  - [ ] mysql: https://github.com/VioletBuse/gmysql
  - [ ] postgresql: https://github.com/lpil/pog
  - [ ] sqlite: https://github.com/lpil/sqlight
- [ ] auto-discover driver in dependencies

- [ ] for unsupported drivers add option to add empty functions for parsing
  - [ ] add `todo` to ensure implementation
  - [ ] make sure we dont accidentally clear them!

- [ ] reuse types if they have the same schema (f.e. select *)

- [ ] auto discover sqlc.yaml/json
  - [ ] how do we handle multiple?
  - [ ] we could do all of them?
    - [ ] one module for each sqlc.yaml/json
    - [ ] name -> parent directory of sqlc config? or from catalog schema name?

- [ ] add "auto generated" comments in head of files similar to...
  - ... https://github.com/sqlc-dev/sqlc/blob/main/examples/batch/postgresql/query.sql.go
