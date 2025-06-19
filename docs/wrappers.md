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

```gleam
```
