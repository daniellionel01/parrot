import app/driver
import app/sql
import gleam/option.{None, Some}
import gleam/time/calendar
import gleam/time/timestamp
import gleeunit

pub fn main() {
  gleeunit.main()
}

const date = calendar.Date(2024, calendar.February, 29)

const time = calendar.TimeOfDay(13, 37, 42, 0)

pub fn smallint_test() {
  let db = driver.connect()
  let query = sql.smallint_round_trip(value: -32_768, nullable_value: Some(1))
  assert driver.query(db, query)
    == Ok([sql.SmallintRoundTrip(value: -32_768, nullable_value: Some(1))])
  let query = sql.smallint_round_trip(value: 1, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.SmallintRoundTrip(value: 1, nullable_value: None)])
}

pub fn integer_test() {
  let db = driver.connect()
  let query =
    sql.integer_round_trip(value: 2_147_483_647, nullable_value: Some(-1))
  assert driver.query(db, query)
    == Ok([sql.IntegerRoundTrip(value: 2_147_483_647, nullable_value: Some(-1))])
  let query = sql.integer_round_trip(value: 1, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.IntegerRoundTrip(value: 1, nullable_value: None)])
}

pub fn bigint_test() {
  let db = driver.connect()
  let big = 9_007_199_254_740_993
  let query = sql.bigint_round_trip(value: big, nullable_value: Some(big))
  assert driver.query(db, query)
    == Ok([sql.BigintRoundTrip(value: big, nullable_value: Some(big))])
  let query = sql.bigint_round_trip(value: big, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.BigintRoundTrip(value: big, nullable_value: None)])
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

pub fn double_test() {
  let db = driver.connect()
  let query = sql.double_round_trip(value: 1.5, nullable_value: Some(-0.25))
  assert driver.query(db, query)
    == Ok([sql.DoubleRoundTrip(value: 1.5, nullable_value: Some(-0.25))])
  let query = sql.double_round_trip(value: 1.5, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.DoubleRoundTrip(value: 1.5, nullable_value: None)])
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

pub fn char_test() {
  let db = driver.connect()
  // char is padded with spaces to its length
  let query = sql.char_round_trip(value: "ab", nullable_value: Some("abcde"))
  assert driver.query(db, query)
    == Ok([sql.CharRoundTrip(value: "ab   ", nullable_value: Some("abcde"))])
  let query = sql.char_round_trip(value: "ab", nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.CharRoundTrip(value: "ab   ", nullable_value: None)])
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

pub fn bytea_test() {
  let db = driver.connect()
  let query =
    sql.bytea_round_trip(value: <<0, 1, 255>>, nullable_value: Some(<<>>))
  assert driver.query(db, query)
    == Ok([sql.ByteaRoundTrip(value: <<0, 1, 255>>, nullable_value: Some(<<>>))])
  let query = sql.bytea_round_trip(value: <<1>>, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.ByteaRoundTrip(value: <<1>>, nullable_value: None)])
}

pub fn uuid_test() {
  let db = driver.connect()
  let uuid = <<0:64, 1:64>>
  let query = sql.uuid_round_trip(value: uuid, nullable_value: Some(uuid))
  assert driver.query(db, query)
    == Ok([sql.UuidRoundTrip(value: uuid, nullable_value: Some(uuid))])
  let query = sql.uuid_round_trip(value: uuid, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.UuidRoundTrip(value: uuid, nullable_value: None)])
}

pub fn json_test() {
  let db = driver.connect()
  let json = "{\"a\":1}"
  let query = sql.json_round_trip(value: json, nullable_value: Some(json))
  assert driver.query(db, query)
    == Ok([sql.JsonRoundTrip(value: json, nullable_value: Some(json))])
  let query = sql.json_round_trip(value: json, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.JsonRoundTrip(value: json, nullable_value: None)])
}

pub fn jsonb_test() {
  let db = driver.connect()
  // jsonb normalises formatting
  let query =
    sql.jsonb_round_trip(value: "{\"a\":1}", nullable_value: Some("{\"a\":1}"))
  assert driver.query(db, query)
    == Ok([
      sql.JsonbRoundTrip(
        value: "{\"a\": 1}",
        nullable_value: Some("{\"a\": 1}"),
      ),
    ])
  let query = sql.jsonb_round_trip(value: "{\"a\":1}", nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.JsonbRoundTrip(value: "{\"a\": 1}", nullable_value: None)])
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

pub fn timestamp_test() {
  let db = driver.connect()
  let ts = timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 123_000)
  let query = sql.timestamp_round_trip(value: ts, nullable_value: Some(ts))
  assert driver.query(db, query)
    == Ok([sql.TimestampRoundTrip(value: ts, nullable_value: Some(ts))])
  let query = sql.timestamp_round_trip(value: ts, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.TimestampRoundTrip(value: ts, nullable_value: None)])
}

pub fn timestamptz_test() {
  let db = driver.connect()
  let ts = timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 123_000)
  let query = sql.timestamptz_round_trip(value: ts, nullable_value: Some(ts))
  assert driver.query(db, query)
    == Ok([sql.TimestamptzRoundTrip(value: ts, nullable_value: Some(ts))])
  let query = sql.timestamptz_round_trip(value: ts, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.TimestamptzRoundTrip(value: ts, nullable_value: None)])
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

pub fn enum_test() {
  let db = driver.connect()
  let query =
    sql.mood_round_trip(value: sql.Happy, nullable_value: Some(sql.Sad))
  assert driver.query(db, query)
    == Ok([sql.MoodRoundTrip(value: sql.Happy, nullable_value: Some(sql.Sad))])
  let query = sql.mood_round_trip(value: sql.Sad, nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.MoodRoundTrip(value: sql.Sad, nullable_value: None)])
}

pub fn text_array_test() {
  let db = driver.connect()
  let query =
    sql.text_array_round_trip(value: ["a", "b"], nullable_value: Some([]))
  assert driver.query(db, query)
    == Ok([sql.TextArrayRoundTrip(value: ["a", "b"], nullable_value: Some([]))])
  let query = sql.text_array_round_trip(value: [], nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.TextArrayRoundTrip(value: [], nullable_value: None)])
}

pub fn integer_array_test() {
  let db = driver.connect()
  let query =
    sql.integer_array_round_trip(value: [1, 2, 3], nullable_value: Some([4]))
  assert driver.query(db, query)
    == Ok([
      sql.IntegerArrayRoundTrip(value: [1, 2, 3], nullable_value: Some([4])),
    ])
  let query = sql.integer_array_round_trip(value: [], nullable_value: None)
  assert driver.query(db, query)
    == Ok([sql.IntegerArrayRoundTrip(value: [], nullable_value: None)])
}

// https://github.com/daniellionel01/parrot/issues/74
pub fn keyword_columns_test() {
  let db = driver.connect()
  let query = sql.keywords_round_trip(type_: "a", case_: "b")
  assert driver.query(db, query)
    == Ok([sql.KeywordsRoundTrip(type_: "a", case_: "b")])
}
