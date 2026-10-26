# Wrappers

## https://github.com/lpil/sqlight

Since [sqlite](https://sqlite.org/) only supports a limited set of data types (https://sqlite.org/datatype3.html),
we do not have to provide implementations for booleans and timestamps.

`dynamic` data types are unlikely in sqlite, but if they should occur (maybe through using an extension)
you can provide your own implementation.

```gleam
pub fn parrot_to_sqlight(param: sql.Param) -> sqlight.Value {
  case param {
    sql.ParamFloat(x) -> sqlight.float(x)
    sql.ParamInt(x) -> sqlight.int(x)
    sql.ParamString(x) -> sqlight.text(x)
    sql.ParamBitArray(x) -> sqlight.blob(x)
    sql.ParamNullable(x) -> sqlight.nullable(fn(a) { parrot_to_sqlight(a) }, x)
    sql.ParamList(_) -> panic as "sqlite does not implement lists"
    sql.ParamBool(_) -> panic as "sqlite does not support booleans"
    sql.ParamDate(_) -> panic as "sqlite does not support dates"
    sql.ParamTimestamp(_) -> panic as "sqlite does not support timestamps"
    sql.ParamTimeOfDay(_) -> panic as "sqlite does not support time of day"
    sql.ParamDynamic(_) -> todo
  }
}
```

## https://github.com/lpil/pog

Postgresql provides a vast amount of simple and complex data types. Parrot is able to map all commonly used data types,
but might struggle with more complex data types such as `polygon`.

```gleam
pub fn parrot_to_pog(param: sql.Param) -> pog.Value {
  case param {
    sql.ParamDynamic(_) -> todo
    sql.ParamBool(x) -> pog.bool(x)
    sql.ParamFloat(x) -> pog.float(x)
    sql.ParamInt(x) -> pog.int(x)
    sql.ParamString(x) -> pog.text(x)
    sql.ParamBitArray(x) -> pog.bytea(x)
    sql.ParamList(x) -> pog.array(parrot_to_pog, x)
    sql.ParamNullable(x) -> pog.nullable(fn(a) { parrot_to_pog(a) }, x)
    sql.ParamDate(x) -> pog.calendar_date(x)
    sql.ParamTimestamp(x) -> pog.timestamp(x)
    sql.ParamTimeOfDay(x) -> pog.calendar_time_of_day(x)
  }
}
```
