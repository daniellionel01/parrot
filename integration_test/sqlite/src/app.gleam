import app/sql
import gleam/list
import gleam/option
import parrot/dev
import sqlight

pub fn main() {
  use on <- sqlight.with_connection("./file.db")

  let #(sql, params) = sql.create_user("bob")

  let #(sql, with, expecting) = sql.get_user_by_username("alice")
  let with = list.map(with, parrot_to_sqlight)
  let assert Ok([
    sql.GetUserByUsername(
      1,
      "alice",
      option.Some(_),
      0.0,
      option.None,
      option.Some(<<31, 128>>),
    ),
  ]) = sqlight.query(sql, on:, with:, expecting:)
}

fn parrot_to_sqlight(param: dev.Param) -> sqlight.Value {
  case param {
    dev.ParamBool(x) -> sqlight.bool(x)
    dev.ParamFloat(x) -> sqlight.float(x)
    dev.ParamInt(x) -> sqlight.int(x)
    dev.ParamString(x) -> sqlight.text(x)
    dev.ParamBitArray(x) -> sqlight.blob(x)
    dev.ParamTimestamp(_) ->
      panic as "timestamp parameter needs to be implemented"
    dev.ParamDynamic(_) -> panic as "cannot process dynamic parameter"
  }
}
