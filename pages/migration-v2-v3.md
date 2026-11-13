# Migrating from v2 to v3

## Parrot is a dev dependency now

Parrot only runs at development time, so it no longer belongs in your
dependencies. Everything that used to live in `parrot/dev` is now part of the
generated module.

```sh
$ gleam remove parrot
$ gleam add --dev parrot
$ gleam run -m parrot
```

Then point your imports at the generated module instead of `parrot/dev`:

```diff
- import parrot/dev
+ import app/sql

- fn to_pog(param: dev.Param) -> pog.Value {
+ fn to_pog(param: sql.Param) -> pog.Value {
    case param {
-     dev.ParamInt(x) -> pog.int(x)
+     sql.ParamInt(x) -> pog.int(x)
```

The decoders moved too, so `dev.datetime_decoder()` becomes
`sql.datetime_decoder()`.

## New `Param` variants

Your wrapper needs to handle four new variants:

```gleam
sql.ParamTimeOfDay(x) -> pog.calendar_time_of_day(x)
sql.ParamInterval(x) -> ...
sql.ParamInet(x) -> ...
sql.ParamMacaddr(x) -> ...
```

pog doesn't ship encoders for `interval`, `inet` or `macaddr`. The
[example driver](https://github.com/daniellionel01/parrot/blob/main/test_projects/postgres/src/app/driver.gleam)
shows one way to write them.

Using sqlight or shork? Their wrappers are in
[wrappers](https://github.com/daniellionel01/parrot/blob/main/pages/wrappers.md).

## Column types that changed

A few postgres columns now decode to better types. Some of the old ones were
just wrong, like `interval` as `Int`.

| Column                  | v2               | v3               |
| ----------------------- | ---------------- | ---------------- |
| postgres `time`         | `Timestamp`      | `TimeOfDay`      |
| postgres `timetz`       | `Timestamp`      | `decode.Dynamic` |
| postgres `interval`     | `Int`            | `Interval`       |
| postgres `char`         | `decode.Dynamic` | `String`         |
| postgres `inet`, `cidr` | `decode.Dynamic` | `Inet`           |
| postgres `macaddr`      | `decode.Dynamic` | `BitArray`       |
