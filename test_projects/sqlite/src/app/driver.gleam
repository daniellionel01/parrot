import app/sql
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import sqlight

pub const path = "file.db"

pub fn connect() -> sqlight.Connection {
  let assert Ok(db) = sqlight.open(path)
  db
}

pub fn query(
  db: sqlight.Connection,
  query: #(String, List(sql.Param), decode.Decoder(a)),
) -> Result(List(a), sqlight.Error) {
  let #(sql, params, decoder) = query
  sqlight.query(
    sql,
    on: db,
    with: list.map(params, to_sqlight),
    expecting: decoder,
  )
}

pub fn exec(
  db: sqlight.Connection,
  query: #(String, List(sql.Param)),
) -> Result(Nil, sqlight.Error) {
  let #(sql, params) = query
  sqlight.query(
    sql,
    on: db,
    with: list.map(params, to_sqlight),
    expecting: decode.success(Nil),
  )
  |> result.replace(Nil)
}

/// sqlite has no date and time types, they are stored as ISO 8601 text.
///
pub fn to_sqlight(param: sql.Param) -> sqlight.Value {
  case param {
    sql.ParamBool(x) -> sqlight.bool(x)
    sql.ParamFloat(x) -> sqlight.float(x)
    sql.ParamInt(x) -> sqlight.int(x)
    sql.ParamString(x) -> sqlight.text(x)
    sql.ParamBitArray(x) -> sqlight.blob(x)
    sql.ParamNullable(x) -> sqlight.nullable(to_sqlight, x)
    sql.ParamDate(x) -> sqlight.text(date_to_string(x))
    sql.ParamTimestamp(x) ->
      sqlight.text(timestamp.to_rfc3339(x, calendar.utc_offset))
    sql.ParamTimeOfDay(x) -> sqlight.text(time_to_string(x))
    sql.ParamInterval(_) | sql.ParamInet(_) | sql.ParamMacaddr(_) ->
      panic as "postgres only"
    sql.ParamList(_) -> panic as "sqlite does not support lists"
    sql.ParamDynamic(_) -> panic as "dynamic parameters are not supported"
  }
}

fn date_to_string(date: calendar.Date) -> String {
  pad(date.year, 4)
  <> "-"
  <> pad(calendar.month_to_int(date.month), 2)
  <> "-"
  <> pad(date.day, 2)
}

fn time_to_string(time: calendar.TimeOfDay) -> String {
  pad(time.hours, 2)
  <> ":"
  <> pad(time.minutes, 2)
  <> ":"
  <> pad(time.seconds, 2)
}

fn pad(value: Int, length: Int) -> String {
  string.pad_start(int.to_string(value), length, "0")
}
