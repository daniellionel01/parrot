import app/sql
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import shork

pub fn connect() -> shork.Connection {
  shork.default_config()
  |> shork.host("127.0.0.1")
  |> shork.port(33_306)
  |> shork.user("root")
  |> shork.password("parrot")
  |> shork.database("parrot_test_project")
  |> shork.connect
}

pub fn query(
  db: shork.Connection,
  query: #(String, List(sql.Param), decode.Decoder(a)),
) -> Result(List(a), shork.QueryError) {
  let #(sql, params, decoder) = query
  list.fold(params, shork.query(sql), fn(query, param) {
    shork.parameter(query, to_shork(param))
  })
  |> shork.returning(decoder)
  |> shork.execute(db)
  |> result.map(fn(returned) { returned.rows })
}

pub fn exec(
  db: shork.Connection,
  statement: #(String, List(sql.Param)),
) -> Result(Nil, shork.QueryError) {
  let #(sql, params) = statement
  query(db, #(sql, params, decode.success(Nil)))
  |> result.replace(Nil)
}

pub fn to_shork(param: sql.Param) -> shork.Value {
  case param {
    // `shork.bool` crashes, mysql-otp can not encode booleans
    sql.ParamBool(True) -> shork.int(1)
    sql.ParamBool(False) -> shork.int(0)
    sql.ParamFloat(x) -> shork.float(x)
    sql.ParamInt(x) -> shork.int(x)
    sql.ParamString(x) -> shork.text(x)
    sql.ParamBitArray(x) -> coerce(x)
    sql.ParamNullable(option.Some(x)) -> to_shork(x)
    sql.ParamNullable(option.None) -> shork.null()
    sql.ParamDate(x) -> shork.calendar_date(x)
    sql.ParamTimestamp(x) -> {
      let #(date, time) = timestamp.to_calendar(x, calendar.utc_offset)
      coerce(#(
        #(date.year, calendar.month_to_int(date.month), date.day),
        #(time.hours, time.minutes, time.seconds),
      ))
    }
    sql.ParamTimeOfDay(x) -> shork.calendar_time_of_day(x)
    sql.ParamList(_) -> panic as "mysql does not support lists"
    sql.ParamDynamic(_) -> panic as "dynamic parameters are not supported"
  }
}

@external(erlang, "gleam_stdlib", "identity")
fn coerce(value: a) -> shork.Value
