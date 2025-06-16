import app/sql
import envoy
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/result
import parrot/dev
import pog

pub fn main() {
  let assert Ok(database_url) = envoy.get("DATABASE_URL")
  use config <- result.try(pog.url_config(database_url))
  let db = pog.connect(config)

  let #(sql, params) = sql.get_user_by_username("alice")
  let assert Ok(pog.Returned(
    1,
    [sql.GetUserByUsername(1, "alice", option.Some(_))],
  )) = query(db, sql, params, sql.get_user_by_username_decoder())

  Ok(Nil)
}

fn parrot_to_pog(param: dev.Param) -> pog.Value {
  case param {
    dev.ParamBool(x) -> pog.bool(x)
    dev.ParamFloat(x) -> pog.float(x)
    dev.ParamInt(x) -> pog.int(x)
    dev.ParamString(x) -> pog.text(x)
    dev.ParamBitArray(x) -> pog.bytea(x)
    dev.ParamTimestamp(_) ->
      panic as "timestamp parameter needs to be implemented"
    dev.ParamDynamic(_) -> panic as "cannot process dynamic parameter"
  }
}

fn query(
  db db: pog.Connection,
  sql sql: String,
  with with: List(dev.Param),
  expecting expecting: decode.Decoder(a),
) {
  sql
  |> pog.query()
  |> pog.returning(expecting)
  |> list.fold(with, _, fn(acc, param) {
    let param = parrot_to_pog(param)
    pog.parameter(acc, param)
  })
  |> pog.execute(db)
}
