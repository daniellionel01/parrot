# todo

## v2

- [ ] support more complex postgres columns
  - [ ] hstore
  - [ ] network address types
        inet, cidr, macaddr, macaddr8
  - [ ] int4range, tsrange
  - [ ] geometric
        point, polygon
  - [ ] interval
  - [ ] tsvector, tsquery
- [ ] provide better decoder for dyn cols
  -> param record add type, column, table
- [ ] provide gleam records for db schema
- [ ] provide clever joining mechanism
- [ ] idea: provide config where you can
      override every de- and encoder
- [ ] improve type api
  - params? gleam types?
  - instead of params maybe sqlctype?
  - db -> sqlc -> gleam | en- & decode

## miscellaneous

- [ ] write tests for timestamp de- and encoder
- [ ] potentially colliding enum definition names from different schemas / catalogs
- [ ] dockerize
- [ ] add type mapping table for psql, mysql, sqlite to gleam type
- [ ] advanced types
  - [ ] set
  - [ ] https://docs.sqlc.dev/en/stable/reference/datatypes.html#geometry

## v1.2.0

- [ ] integration managed db (https://docs.sqlc.dev/en/latest/howto/managed-databases.html)
- [ ] pg_lsn
