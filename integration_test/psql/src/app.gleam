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

  let #(sql, params, expecting) = sql.get_user_by_username("alice")
  let assert Ok(pog.Returned(
    1,
    [
      sql.GetUserByUsername(
        3,
        "alice",
        option.Some(_),
        option.Some("{\"a\": 1, \"b\": 2}"),
        option.Some("{\"c\": 3}"),
        option.Some([3, 11]),
        option.Some(sql.User),
        option.Some(<<222, 173, 190, 239>>),
      ),
    ],
  )) = query(db, sql, params, expecting)
  // echo query(db, sql, params, decode.dynamic)

  Ok(Nil)
}

fn parrot_to_pog(param: dev.Param) -> pog.Value {
  case param {
    dev.ParamBool(x) -> pog.bool(x)
    dev.ParamFloat(x) -> pog.float(x)
    dev.ParamInt(x) -> pog.int(x)
    dev.ParamString(x) -> pog.text(x)
    dev.ParamBitArray(x) -> pog.bytea(x)
    dev.ParamList(x) -> pog.array(parrot_to_pog, x)
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
