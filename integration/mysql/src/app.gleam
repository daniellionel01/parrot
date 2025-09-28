import app/sql
import gleam/dynamic/decode
import gleam/list
import gleam/option
import parrot/dev
import shork

pub fn main() {
  let db =
    shork.default_config()
    |> shork.user("root")
    |> shork.password("daniel")
    |> shork.database("parrot")
    |> shork.port(3309)
    |> shork.connect

  let #(sql, params, expecting) = sql.get_user_by_username("alice")
  let assert Ok(shork.Returned(
    ["id", "username", "created_at", "status", "admin"],
    [sql.GetUserByUsername(1, "alice", option.Some(_), option.None, True)],
  )) = query(db, sql, params, expecting)

  Ok(Nil)
}

fn parrot_to_shork(param: dev.Param) {
  case param {
    dev.ParamBool(x) -> shork.bool(x)
    dev.ParamFloat(x) -> shork.float(x)
    dev.ParamInt(x) -> shork.int(x)
    dev.ParamString(x) -> shork.text(x)
    dev.ParamNullable(_) ->
      panic as "shork does not support nullable parameters"
    dev.ParamList(_) -> panic as "shork does not support lists"
    dev.ParamBitArray(_) -> panic as "shork does not support bit arrays"
    dev.ParamDate(_) -> panic as "date parameter needs to be implemented"
    dev.ParamTimestamp(_) ->
      panic as "timestamp parameter needs to be implemented"
    dev.ParamDynamic(_) -> panic as "dynamic parameter need to implemented"
  }
}

fn query(
  db db: shork.Connection,
  sql sql: String,
  with with: List(dev.Param),
  expecting expecting: decode.Decoder(a),
) {
  sql
  |> shork.query()
  |> shork.returning(expecting)
  |> list.fold(with, _, fn(acc, param) {
    let param = parrot_to_shork(param)
    shork.parameter(acc, param)
  })
  |> shork.execute(db)
}
