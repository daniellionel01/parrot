import app/sql
import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/result
import gleam/time/calendar
import parrot/dev
import pog

pub fn main() {
  let name = process.new_name("pog")

  let assert Ok(database_url) = envoy.get("DATABASE_URL")
  use config <- result.try(pog.url_config(name, database_url))
  let assert Ok(db) = pog.start(config)

  let _ = test_getting_user_by_username(db.data)
  let _ = test_creating_user_with_date(db.data)

  process.send_exit(db.pid)

  Ok(Nil)
}

/// Test getting user by username
fn test_getting_user_by_username(db: pog.Connection) {
  let #(sql, params, expecting) = sql.get_user_by_username("alice")
  let assert Ok(pog.Returned(
    1,
    [
      sql.GetUserByUsername(
        id: 3,
        username: "alice",
        created_at: option.Some(_),
        date_of_birth: option.None,
        profile: option.Some("{\"a\": 1, \"b\": 2}"),
        extra_info: option.Some("{\"c\": 3}"),
        favorite_numbers: option.Some([3, 11]),
        role: option.Some(sql.User),
        document: option.Some(<<222, 173, 190, 239>>),
      ),
    ],
  )) = query(db, sql, params, expecting)
}

/// Test creating user with timestamp and date
fn test_creating_user_with_date(db: pog.Connection) {
  let #(sql, params) =
    sql.create_user_with_date_of_birth("freddy", "1995-04-04")
  let assert Ok(_result) = exec(db, sql, params)

  let #(sql, params, expecting) = sql.get_user_by_username("freddy")
  let result = query(db, sql, params, expecting)

  let assert Ok(pog.Returned(
    1,
    [
      sql.GetUserByUsername(
        id: 4,
        username: "freddy",
        created_at: option.Some(_),
        date_of_birth: option.Some(calendar.Date(1995, calendar.April, 4)),
        profile: option.None,
        extra_info: option.None,
        favorite_numbers: option.None,
        role: option.None,
        document: option.None,
      ),
    ],
  )) = result
}

fn parrot_to_pog(param: dev.Param) -> pog.Value {
  case param {
    dev.ParamBool(x) -> pog.bool(x)
    dev.ParamFloat(x) -> pog.float(x)
    dev.ParamInt(x) -> pog.int(x)
    dev.ParamString(x) -> pog.text(x)
    dev.ParamBitArray(x) -> pog.bytea(x)
    dev.ParamList(x) -> pog.array(parrot_to_pog, x)
    dev.ParamNullable(x) -> pog.nullable(parrot_to_pog, x)
    dev.ParamDate(x) -> pog.calendar_date(x)
    dev.ParamTimestamp(x) -> pog.timestamp(x)
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

fn exec(db db: pog.Connection, sql sql: String, with with: List(dev.Param)) {
  sql
  |> pog.query()
  |> list.fold(with, _, fn(acc, param) {
    let param = parrot_to_pog(param)
    pog.parameter(acc, param)
  })
  |> pog.execute(db)
}
