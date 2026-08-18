import app/sql
import gleam/dynamic/decode
import gleam/list
import gleam/option
import sqlight

pub fn main() {
  use on <- sqlight.with_connection("./file.db")

  let #(sql, with) = sql.create_user("danny")
  let with = list.map(with, parrot_to_sqlight)
  let assert Ok(_) =
    sqlight.query(sql, on:, with:, expecting: decode.success(""))

  let #(sql, with, expecting) = sql.count_users()
  let with = list.map(with, parrot_to_sqlight)
  let assert Ok([sql.CountUsers(4)]) =
    sqlight.query(sql, on:, with:, expecting:)

  let #(sql, with, expecting) = sql.get_user_by_username("alice")
  let with = list.map(with, parrot_to_sqlight)
  let assert Ok([
    sql.GetUserByUsername(
      3,
      "alice",
      option.Some(_),
      0.0,
      option.None,
      option.None,
      option.Some(<<31, 128>>),
      option.None,
    ),
  ]) = sqlight.query(sql, on:, with:, expecting:)
}

fn parrot_to_sqlight(param: sql.Param) -> sqlight.Value {
  case param {
    sql.ParamBool(x) -> sqlight.bool(x)
    sql.ParamFloat(x) -> sqlight.float(x)
    sql.ParamInt(x) -> sqlight.int(x)
    sql.ParamString(x) -> sqlight.text(x)
    sql.ParamBitArray(x) -> sqlight.blob(x)
    sql.ParamNullable(x) -> sqlight.nullable(fn(a) { parrot_to_sqlight(a) }, x)
    sql.ParamList(_) -> panic as "sqlite does not implement lists"
    sql.ParamDate(_) -> panic as "date parameter needs to be implemented"
    sql.ParamTimestamp(_) -> panic as "sqlite does not support timestamps"
    sql.ParamDynamic(_) -> panic as "cannot process dynamic parameter"
  }
}
