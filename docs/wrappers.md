# Wrappers

## https://github.com/lpil/sqlight

Since [sqlite](https://sqlite.org/) only supports a limited set of data types (https://sqlite.org/datatype3.html),
we do not have to provide implementations for booleans and timestamps.

`dynamic` data types are unlikely in sqlite, but if they should occur (maybe through using an extension)
you can provide your own implementation.

```gleam
fn parrot_to_sqlight(param: dev.Param) -> sqlight.Value {
  case param {
    dev.ParamFloat(x) -> sqlight.float(x)
    dev.ParamInt(x) -> sqlight.int(x)
    dev.ParamString(x) -> sqlight.text(x)
    dev.ParamBitArray(x) -> sqlight.blob(x)
    dev.ParamBool(_) -> panic as "sqlite does not support booleans"
    dev.ParamTimestamp(_) -> panic as "sqlite does not support timestamps"
    dev.ParamDynamic(_) -> todo
  }
}
```

## https://github.com/lpil/pog

Postgresql provides a vast amount of simple and complex data types. Parrot is able to map all commonly used data types,
but might struggle with more complex data types such as `polygon`.

```gleam
pub fn parrot_to_pog(param: parrot.Param) -> pog.Value {
  case param {
    parrot.ParamDynamic(_) -> todo
    parrot.ParamBool(x) -> pog.bool(x)
    parrot.ParamFloat(x) -> pog.float(x)
    parrot.ParamInt(x) -> pog.int(x)
    parrot.ParamString(x) -> pog.text(x)
    parrot.ParamBitArray(x) -> pog.bytea(x)
    parrot.ParamTimestamp(x) -> {
      let #(date, time) = timestamp.to_calendar(x, calendar.utc_offset)

      pog.timestamp(pog.Timestamp(
        pog.Date(
          year: date.year,
          month: calendar.month_to_int(date.month),
          day: date.day,
        ),
        pog.Time(
          hours: time.hours,
          minutes: time.minutes,
          seconds: time.seconds,
          microseconds: time.nanoseconds / 1000,
        ),
      ))
    }
  }
}
```
