# Migration Guide v2 -> v3

## Dev dependency

Parrot is now a dev dependency. Everything from `parrot/dev` is part of the generated module.

```sh
$ gleam remove parrot
$ gleam add --dev parrot
$ gleam run -m parrot
```

Replace `parrot/dev` with your generated module:

```diff
- import parrot/dev
+ import app/sql

- fn to_pog(param: dev.Param) -> pog.Value {
+ fn to_pog(param: sql.Param) -> pog.Value {
    case param {
-     dev.ParamInt(x) -> pog.int(x)
+     sql.ParamInt(x) -> pog.int(x)
```

Same for the decoders, f.e. `dev.datetime_decoder()` -> `sql.datetime_decoder()`.

## New `Param` variants

Add them to your wrapper:

```gleam
sql.ParamTimeOfDay(x) -> pog.calendar_time_of_day(x)
sql.ParamInterval(x) -> ...
sql.ParamInet(x) -> ...
sql.ParamMacaddr(x) -> ...
```

pog has no encoders for `interval`, `inet` and `macaddr`, see the pog [driver.gleam](https://github.com/daniellionel01/parrot/blob/main/test_projects/postgres/src/app/driver.gleam).

See [wrappers](https://github.com/daniellionel01/parrot/blob/main/pages/wrappers.md) for sqlight and shork.

## Changed types

| Column                  | v2               | v3               |
| ----------------------- | ---------------- | ---------------- |
| postgres `time`         | `Timestamp`      | `TimeOfDay`      |
| postgres `timetz`       | `Timestamp`      | `decode.Dynamic` |
| postgres `interval`     | `Int`            | `Interval`       |
| postgres `char`         | `decode.Dynamic` | `String`         |
| postgres `inet`, `cidr` | `decode.Dynamic` | `Inet`           |
| postgres `macaddr`      | `decode.Dynamic` | `BitArray`       |
