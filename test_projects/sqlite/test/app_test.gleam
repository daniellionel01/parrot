import app/driver
import app/sql
import gleam/list
import gleam/option.{None, Some}
import gleam/time/calendar
import gleam/time/timestamp
import gleeunit

pub fn main() {
  gleeunit.main()
}

const date = calendar.Date(2024, calendar.February, 29)

const time = calendar.TimeOfDay(13, 37, 42, 0)

pub fn integer_test() {
  let db = driver.connect()
  let big = 9_007_199_254_740_993
  let query = sql.integer_round_trip(value: big, nullable_value: Some(-1))
  assert driver.query(db, query)
    == Ok([sql.IntegerRoundTrip(value: big, nullable_value: Some(-1))])
  let query = sql.integer_round_trip(value: 1, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.IntegerRoundTrip(value: 1, nullable_value: None)])
}

pub fn real_test() {
  let db = driver.connect()
  let query = sql.real_round_trip(value: 1.5, nullable_value: Some(-0.25))
  assert driver.query(db, query)
    == Ok([sql.RealRoundTrip(value: 1.5, nullable_value: Some(-0.25))])
  let query = sql.real_round_trip(value: 1.5, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.RealRoundTrip(value: 1.5, nullable_value: None)])
}

pub fn numeric_test() {
  let db = driver.connect()
  let query = sql.numeric_round_trip(value: 12.5, nullable_value: Some(-0.25))
  assert driver.query(db, query)
    == Ok([sql.NumericRoundTrip(value: 12.5, nullable_value: Some(-0.25))])
  let query = sql.numeric_round_trip(value: 12.5, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.NumericRoundTrip(value: 12.5, nullable_value: None)])
}

pub fn text_test() {
  let db = driver.connect()
  let query = sql.text_round_trip(value: "hello 🦜", nullable_value: Some(""))
  assert driver.query(db, query)
    == Ok([sql.TextRoundTrip(value: "hello 🦜", nullable_value: Some(""))])
  let query = sql.text_round_trip(value: "a", nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.TextRoundTrip(value: "a", nullable_value: None)])
}

pub fn varchar_test() {
  let db = driver.connect()
  let query = sql.varchar_round_trip(value: "hello", nullable_value: Some("b"))
  assert driver.query(db, query)
    == Ok([sql.VarcharRoundTrip(value: "hello", nullable_value: Some("b"))])
  let query = sql.varchar_round_trip(value: "a", nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.VarcharRoundTrip(value: "a", nullable_value: None)])
}

pub fn blob_test() {
  let db = driver.connect()
  let query =
    sql.blob_round_trip(value: <<0, 1, 255>>, nullable_value: Some(<<>>))
  assert driver.query(db, query)
    == Ok([sql.BlobRoundTrip(value: <<0, 1, 255>>, nullable_value: Some(<<>>))])
  let query = sql.blob_round_trip(value: <<1>>, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.BlobRoundTrip(value: <<1>>, nullable_value: None)])
}

pub fn boolean_test() {
  let db = driver.connect()
  let query = sql.boolean_round_trip(value: True, nullable_value: Some(False))
  assert driver.query(db, query)
    == Ok([sql.BooleanRoundTrip(value: True, nullable_value: Some(False))])
  let query = sql.boolean_round_trip(value: False, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.BooleanRoundTrip(value: False, nullable_value: None)])
}

pub fn date_test() {
  let db = driver.connect()
  let query = sql.date_round_trip(value: date, nullable_value: Some(date))
  assert driver.query(db, query)
    == Ok([sql.DateRoundTrip(value: date, nullable_value: Some(date))])
  let query = sql.date_round_trip(value: date, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.DateRoundTrip(value: date, nullable_value: None)])
}

pub fn datetime_test() {
  let db = driver.connect()
  let ts = timestamp.from_unix_seconds(1_700_000_000)
  let query = sql.datetime_round_trip(value: ts, nullable_value: Some(ts))
  assert driver.query(db, query)
    == Ok([sql.DatetimeRoundTrip(value: ts, nullable_value: Some(ts))])
  let query = sql.datetime_round_trip(value: ts, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.DatetimeRoundTrip(value: ts, nullable_value: None)])
}

pub fn timestamp_test() {
  let db = driver.connect()
  let ts = timestamp.from_unix_seconds(1_700_000_000)
  let query = sql.timestamp_round_trip(value: ts, nullable_value: Some(ts))
  assert driver.query(db, query)
    == Ok([sql.TimestampRoundTrip(value: ts, nullable_value: Some(ts))])
  let query = sql.timestamp_round_trip(value: ts, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.TimestampRoundTrip(value: ts, nullable_value: None)])
}

pub fn time_test() {
  let db = driver.connect()
  let query = sql.time_round_trip(value: time, nullable_value: Some(time))
  assert driver.query(db, query)
    == Ok([sql.TimeRoundTrip(value: time, nullable_value: Some(time))])
  let query = sql.time_round_trip(value: time, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.TimeRoundTrip(value: time, nullable_value: None)])
}

pub fn slice_test() {
  let db = driver.connect()
  let assert Ok(Nil) =
    [1, 2, 3]
    |> list.try_each(fn(value) { driver.exec(db, sql.insert_slice(value:)) })

  assert driver.query(db, sql.select_slice(values: [1, 3]))
    == Ok([sql.SelectSlice(1), sql.SelectSlice(3)])
  assert driver.query(db, sql.select_slice(values: [2]))
    == Ok([sql.SelectSlice(2)])
  assert driver.query(db, sql.select_slice(values: [])) == Ok([])
}

// https://github.com/daniellionel01/parrot/issues/74
pub fn keyword_columns_test() {
  let db = driver.connect()
  let query = sql.keywords_round_trip(type_: "a", case_: "b")
  assert driver.query(db, query)
    == Ok([sql.KeywordsRoundTrip(type_: "a", case_: "b")])
}
