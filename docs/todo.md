# todo

## v2

- [ ] support columns
  - [ ] postgres hstore
  - [ ] postgres network address types
        inet, cidr, macaddr, macaddr8
  - [ ] postgres int4range, tsrange
  - [ ] postgres geometric
        point, polygon
  - [ ] postgres interval
  - [ ] postgres tsvector
- [ ] provide better decoder for dyn cols
  -> param record add type, column, table
- [ ] provide gleam types for db schema
- [ ] provide clever joining mechanism
- [ ] idea: provide config where you can
      override every de- and encoder
- [ ] improve type api
  - params? gleam types?
  - instead of params maybe sqlctype?
  - db -> sqlc -> gleam | en- & decode

## miscellaneous

- [ ] further integration tests
  - [ ] mysql
    - [x] test exec queries
    - [ ] advanced types
  - [ ] psql
    - [x] test exec queries
    - [ ] advanced types
  - [ ] sqlite
    - [x] test exec queries

- [ ] advanced types
  - [ ] mysql: enum & set
  - [ ] https://docs.sqlc.dev/en/stable/reference/datatypes.html#geometry
  - [ ] psql: interval, json, jsonb, macaddr <> _, path, pg_lsn, pg_snapshot, point, polygon, tsquery, tsquery, txid_snapshot, xml, lseg, line, inet, box, bytea

## v1.1.0

- [ ] merge `decoder` module into `dev`
- [ ] write tests for timestamp de- and encoder
- [ ] postgres enum
- [ ] mysql enum
- [ ] use assert syntax
- [ ] update wrappers
