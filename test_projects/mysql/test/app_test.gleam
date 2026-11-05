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

/// mysql has no `returning`, so we insert and select the last inserted row
fn round_trip(insert, select) {
  let db = driver.connect()
  let assert Ok(Nil) = driver.exec(db, insert)
  driver.query(db, select)
}

pub fn null_test() {
  assert round_trip(sql.insert_integer(1, None), sql.select_integer())
    == Ok([sql.SelectInteger(1, None)])
}

pub fn int_test() {
  assert round_trip(sql.insert_tinyint(1, Some(2)), sql.select_tinyint())
    == Ok([sql.SelectTinyint(1, Some(2))])
  assert round_trip(sql.insert_integer(1, Some(2)), sql.select_integer())
    == Ok([sql.SelectInteger(1, Some(2))])
  assert round_trip(sql.insert_unsigned(1, Some(2)), sql.select_unsigned())
    == Ok([sql.SelectUnsigned(1, Some(2))])
  assert round_trip(sql.insert_bigint(1, Some(2)), sql.select_bigint())
    == Ok([sql.SelectBigint(1, Some(2))])
}

pub fn float_test() {
  assert round_trip(sql.insert_float(1.5, Some(2.5)), sql.select_float())
    == Ok([sql.SelectFloat(1.5, Some(2.5))])
  assert round_trip(sql.insert_double(1.5, Some(2.5)), sql.select_double())
    == Ok([sql.SelectDouble(1.5, Some(2.5))])
  assert round_trip(sql.insert_decimal(1.5, Some(2.5)), sql.select_decimal())
    == Ok([sql.SelectDecimal(1.5, Some(2.5))])
}

pub fn string_test() {
  assert round_trip(sql.insert_varchar("a", Some("b")), sql.select_varchar())
    == Ok([sql.SelectVarchar("a", Some("b"))])
  assert round_trip(sql.insert_text("a", Some("b")), sql.select_text())
    == Ok([sql.SelectText("a", Some("b"))])
  assert round_trip(sql.insert_json("{}", Some("[]")), sql.select_json())
    == Ok([sql.SelectJson("{}", Some("[]"))])
}

pub fn bool_test() {
  assert round_trip(sql.insert_boolean(True, Some(False)), sql.select_boolean())
    == Ok([sql.SelectBoolean(True, Some(False))])
}

pub fn blob_test() {
  assert round_trip(sql.insert_blob(<<1, 2>>, Some(<<3>>)), sql.select_blob())
    == Ok([sql.SelectBlob(<<1, 2>>, Some(<<3>>))])
}

pub fn time_test() {
  let date = calendar.Date(2024, calendar.March, 1)
  assert round_trip(sql.insert_date(date, Some(date)), sql.select_date())
    == Ok([sql.SelectDate(date, Some(date))])

  let ts = timestamp.from_unix_seconds(1_700_000_000)
  assert round_trip(sql.insert_datetime(ts, Some(ts)), sql.select_datetime())
    == Ok([sql.SelectDatetime(ts, Some(ts))])
  assert round_trip(sql.insert_timestamp(ts, Some(ts)), sql.select_timestamp())
    == Ok([sql.SelectTimestamp(ts, Some(ts))])

  let time = calendar.TimeOfDay(12, 30, 0, 0)
  assert round_trip(sql.insert_time(time, Some(time)), sql.select_time())
    == Ok([sql.SelectTime(time, Some(time))])
}

pub fn enum_test() {
  assert round_trip(
      sql.insert_mood(sql.Happy, Some(sql.Mad)),
      sql.select_mood(),
    )
    == Ok([sql.SelectMood(sql.Happy, Some(sql.Mad))])
}

pub fn slice_test() {
  let db = driver.connect()
  let assert Ok(Nil) =
    list.try_each([1, 2, 3], fn(value) {
      driver.exec(db, sql.insert_slice(value:))
    })

  assert driver.query(db, sql.select_slice([1, 3]))
    == Ok([sql.SelectSlice(1), sql.SelectSlice(3)])
  assert driver.query(db, sql.select_slice([])) == Ok([])
}

// https://github.com/daniellionel01/parrot/issues/74
pub fn keyword_columns_test() {
  assert round_trip(sql.insert_keywords("a", "b"), sql.select_keywords())
    == Ok([sql.SelectKeywords(type_: "a", case_: "b")])
}
