import app/driver
import app/sql
import gleam/option.{None, Some}
import gleam/time/calendar
import gleam/time/timestamp
import gleeunit

pub fn main() {
  gleeunit.main()
}

fn query(query) {
  driver.query(driver.connect(), query)
}

pub fn null_test() {
  assert query(sql.integer_round_trip(value: 1, nullable_value: None))
    == Ok([sql.IntegerRoundTrip(1, None)])
}

pub fn int_test() {
  assert query(sql.smallint_round_trip(1, Some(2)))
    == Ok([sql.SmallintRoundTrip(1, Some(2))])
  assert query(sql.integer_round_trip(1, Some(2)))
    == Ok([sql.IntegerRoundTrip(1, Some(2))])
  assert query(sql.bigint_round_trip(1, Some(2)))
    == Ok([sql.BigintRoundTrip(1, Some(2))])
}

pub fn float_test() {
  assert query(sql.real_round_trip(1.5, Some(2.5)))
    == Ok([sql.RealRoundTrip(1.5, Some(2.5))])
  assert query(sql.double_round_trip(1.5, Some(2.5)))
    == Ok([sql.DoubleRoundTrip(1.5, Some(2.5))])
  assert query(sql.numeric_round_trip(1.5, Some(2.5)))
    == Ok([sql.NumericRoundTrip(1.5, Some(2.5))])
}

pub fn string_test() {
  assert query(sql.text_round_trip("a", Some("b")))
    == Ok([sql.TextRoundTrip("a", Some("b"))])
  assert query(sql.varchar_round_trip("a", Some("b")))
    == Ok([sql.VarcharRoundTrip("a", Some("b"))])
  // char is padded with spaces
  assert query(sql.char_round_trip("a", Some("b")))
    == Ok([sql.CharRoundTrip("a    ", Some("b    "))])
}

pub fn bool_test() {
  assert query(sql.boolean_round_trip(True, Some(False)))
    == Ok([sql.BooleanRoundTrip(True, Some(False))])
}

pub fn bit_array_test() {
  assert query(sql.bytea_round_trip(<<1, 2>>, Some(<<3>>)))
    == Ok([sql.ByteaRoundTrip(<<1, 2>>, Some(<<3>>))])
  let uuid = <<1:128>>
  assert query(sql.uuid_round_trip(uuid, Some(uuid)))
    == Ok([sql.UuidRoundTrip(uuid, Some(uuid))])
}

pub fn json_test() {
  assert query(sql.json_round_trip("{\"a\":1}", Some("{}")))
    == Ok([sql.JsonRoundTrip("{\"a\":1}", Some("{}"))])
  // jsonb is normalised
  assert query(sql.jsonb_round_trip("{\"a\":1}", Some("{}")))
    == Ok([sql.JsonbRoundTrip("{\"a\": 1}", Some("{}"))])
}

pub fn time_test() {
  let date = calendar.Date(2024, calendar.March, 1)
  assert query(sql.date_round_trip(date, Some(date)))
    == Ok([sql.DateRoundTrip(date, Some(date))])

  let ts = timestamp.from_unix_seconds(1_700_000_000)
  assert query(sql.timestamp_round_trip(ts, Some(ts)))
    == Ok([sql.TimestampRoundTrip(ts, Some(ts))])
  assert query(sql.timestamptz_round_trip(ts, Some(ts)))
    == Ok([sql.TimestamptzRoundTrip(ts, Some(ts))])

  let time = calendar.TimeOfDay(12, 30, 0, 0)
  assert query(sql.time_round_trip(time, Some(time)))
    == Ok([sql.TimeRoundTrip(time, Some(time))])
}

pub fn enum_test() {
  assert query(sql.mood_round_trip(sql.Happy, Some(sql.Sad)))
    == Ok([sql.MoodRoundTrip(sql.Happy, Some(sql.Sad))])
}

pub fn enum_array_test() {
  assert query(sql.mood_array_round_trip([sql.Happy, sql.Sad], Some([])))
    == Ok([sql.MoodArrayRoundTrip([sql.Happy, sql.Sad], Some([]))])
}

pub fn array_test() {
  assert query(sql.text_array_round_trip(["a", "b"], Some([])))
    == Ok([sql.TextArrayRoundTrip(["a", "b"], Some([]))])
  assert query(sql.integer_array_round_trip([1, 2], Some([])))
    == Ok([sql.IntegerArrayRoundTrip([1, 2], Some([]))])
}

// https://github.com/daniellionel01/parrot/issues/74
pub fn keyword_columns_test() {
  assert query(sql.keywords_round_trip(type_: "a", case_: "b"))
    == Ok([sql.KeywordsRoundTrip(type_: "a", case_: "b")])
}
