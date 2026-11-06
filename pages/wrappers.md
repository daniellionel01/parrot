# Wrappers

Convert `sql.Param` to your database driver's value type. Copy the `to_*` function into your project.

These are tested against real databases in [test_projects](../test_projects).

- [pog](https://github.com/lpil/pog) (PostgreSQL): [driver.gleam](../test_projects/postgres/src/app/driver.gleam)
- [sqlight](https://github.com/lpil/sqlight) (SQLite): [driver.gleam](../test_projects/sqlite/src/app/driver.gleam)
- [shork](https://github.com/ninanomenon/shork) (MySQL): [driver.gleam](../test_projects/mysql/src/app/driver.gleam)

## Quirks

- SQLite has no date and time types. Dates, timestamps and times are stored as ISO 8601 text.
- MySQL: `shork.bool` crashes as a query parameter, booleans are sent as `1` / `0`.
- MySQL has no arrays, so `ParamList` is not supported.
- pog has no encoders for `ParamInterval`, `ParamInet` and `ParamMacaddr`. The pog driver passes the tuples pog expects with an identity FFI.
