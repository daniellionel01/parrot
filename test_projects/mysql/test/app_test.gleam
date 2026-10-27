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

fn round_trip(insert, select) {
  let db = driver.connect()
  let assert Ok(Nil) = driver.exec(db, insert)
  driver.query(db, select)
}

pub fn tinyint_test() {
  assert round_trip(
      sql.insert_tinyint(value: -128, nullable_value: Some(1)),
      sql.select_tinyint(),
    )
    == Ok([sql.SelectTinyint(value: -128, nullable_value: Some(1))])
  assert round_trip(
      sql.insert_tinyint(value: 1, nullable_value: None),
      sql.select_tinyint(),
    )
    == Ok([sql.SelectTinyint(value: 1, nullable_value: None)])
}

pub fn integer_test() {
  assert round_trip(
      sql.insert_integer(value: 2_147_483_647, nullable_value: Some(-1)),
      sql.select_integer(),
    )
    == Ok([sql.SelectInteger(value: 2_147_483_647, nullable_value: Some(-1))])
  assert round_trip(
      sql.insert_integer(value: 1, nullable_value: None),
      sql.select_integer(),
    )
    == Ok([sql.SelectInteger(value: 1, nullable_value: None)])
}

pub fn unsigned_test() {
  assert round_trip(
      sql.insert_unsigned(value: 4_294_967_295, nullable_value: Some(0)),
      sql.select_unsigned(),
    )
    == Ok([sql.SelectUnsigned(value: 4_294_967_295, nullable_value: Some(0))])
  assert round_trip(
      sql.insert_unsigned(value: 1, nullable_value: None),
      sql.select_unsigned(),
    )
    == Ok([sql.SelectUnsigned(value: 1, nullable_value: None)])
}

pub fn bigint_test() {
  let big = 9_007_199_254_740_993
  assert round_trip(
      sql.insert_bigint(value: big, nullable_value: Some(big)),
      sql.select_bigint(),
    )
    == Ok([sql.SelectBigint(value: big, nullable_value: Some(big))])
  assert round_trip(
      sql.insert_bigint(value: big, nullable_value: None),
      sql.select_bigint(),
    )
    == Ok([sql.SelectBigint(value: big, nullable_value: None)])
}

pub fn float_test() {
  assert round_trip(
      sql.insert_float(value: 1.5, nullable_value: Some(-0.25)),
      sql.select_float(),
    )
    == Ok([sql.SelectFloat(value: 1.5, nullable_value: Some(-0.25))])
  assert round_trip(
      sql.insert_float(value: 1.5, nullable_value: None),
      sql.select_float(),
    )
    == Ok([sql.SelectFloat(value: 1.5, nullable_value: None)])
}

pub fn double_test() {
  assert round_trip(
      sql.insert_double(value: 1.5, nullable_value: Some(-0.25)),
      sql.select_double(),
    )
    == Ok([sql.SelectDouble(value: 1.5, nullable_value: Some(-0.25))])
  assert round_trip(
      sql.insert_double(value: 1.5, nullable_value: None),
      sql.select_double(),
    )
    == Ok([sql.SelectDouble(value: 1.5, nullable_value: None)])
}

pub fn decimal_test() {
  assert round_trip(
      sql.insert_decimal(value: 12.5, nullable_value: Some(-0.25)),
      sql.select_decimal(),
    )
    == Ok([sql.SelectDecimal(value: 12.5, nullable_value: Some(-0.25))])
  assert round_trip(
      sql.insert_decimal(value: 12.5, nullable_value: None),
      sql.select_decimal(),
    )
    == Ok([sql.SelectDecimal(value: 12.5, nullable_value: None)])
}

pub fn varchar_test() {
  assert round_trip(
      sql.insert_varchar(value: "hello", nullable_value: Some("")),
      sql.select_varchar(),
    )
    == Ok([sql.SelectVarchar(value: "hello", nullable_value: Some(""))])
  assert round_trip(
      sql.insert_varchar(value: "a", nullable_value: None),
      sql.select_varchar(),
    )
    == Ok([sql.SelectVarchar(value: "a", nullable_value: None)])
}

pub fn text_test() {
  assert round_trip(
      sql.insert_text(value: "hello 🦜", nullable_value: Some("b")),
      sql.select_text(),
    )
    == Ok([sql.SelectText(value: "hello 🦜", nullable_value: Some("b"))])
  assert round_trip(
      sql.insert_text(value: "a", nullable_value: None),
      sql.select_text(),
    )
    == Ok([sql.SelectText(value: "a", nullable_value: None)])
}

pub fn blob_test() {
  assert round_trip(
      sql.insert_blob(value: <<0, 1, 255>>, nullable_value: Some(<<>>)),
      sql.select_blob(),
    )
    == Ok([sql.SelectBlob(value: <<0, 1, 255>>, nullable_value: Some(<<>>))])
  assert round_trip(
      sql.insert_blob(value: <<1>>, nullable_value: None),
      sql.select_blob(),
    )
    == Ok([sql.SelectBlob(value: <<1>>, nullable_value: None)])
}

pub fn boolean_test() {
  assert round_trip(
      sql.insert_boolean(value: True, nullable_value: Some(False)),
      sql.select_boolean(),
    )
    == Ok([sql.SelectBoolean(value: True, nullable_value: Some(False))])
  assert round_trip(
      sql.insert_boolean(value: False, nullable_value: None),
      sql.select_boolean(),
    )
    == Ok([sql.SelectBoolean(value: False, nullable_value: None)])
}

pub fn date_test() {
  assert round_trip(
      sql.insert_date(value: date, nullable_value: Some(date)),
      sql.select_date(),
    )
    == Ok([sql.SelectDate(value: date, nullable_value: Some(date))])
  assert round_trip(
      sql.insert_date(value: date, nullable_value: None),
      sql.select_date(),
    )
    == Ok([sql.SelectDate(value: date, nullable_value: None)])
}

pub fn datetime_test() {
  let ts = timestamp.from_unix_seconds(1_700_000_000)
  assert round_trip(
      sql.insert_datetime(value: ts, nullable_value: Some(ts)),
      sql.select_datetime(),
    )
    == Ok([sql.SelectDatetime(value: ts, nullable_value: Some(ts))])
  assert round_trip(
      sql.insert_datetime(value: ts, nullable_value: None),
      sql.select_datetime(),
    )
    == Ok([sql.SelectDatetime(value: ts, nullable_value: None)])
}

pub fn timestamp_test() {
  let ts = timestamp.from_unix_seconds(1_700_000_000)
  assert round_trip(
      sql.insert_timestamp(value: ts, nullable_value: Some(ts)),
      sql.select_timestamp(),
    )
    == Ok([sql.SelectTimestamp(value: ts, nullable_value: Some(ts))])
  assert round_trip(
      sql.insert_timestamp(value: ts, nullable_value: None),
      sql.select_timestamp(),
    )
    == Ok([sql.SelectTimestamp(value: ts, nullable_value: None)])
}

pub fn time_test() {
  assert round_trip(
      sql.insert_time(value: time, nullable_value: Some(time)),
      sql.select_time(),
    )
    == Ok([sql.SelectTime(value: time, nullable_value: Some(time))])
  assert round_trip(
      sql.insert_time(value: time, nullable_value: None),
      sql.select_time(),
    )
    == Ok([sql.SelectTime(value: time, nullable_value: None)])
}

pub fn json_test() {
  let json = "{\"a\": 1}"
  assert round_trip(
      sql.insert_json(value: json, nullable_value: Some(json)),
      sql.select_json(),
    )
    == Ok([sql.SelectJson(value: json, nullable_value: Some(json))])
  assert round_trip(
      sql.insert_json(value: json, nullable_value: None),
      sql.select_json(),
    )
    == Ok([sql.SelectJson(value: json, nullable_value: None)])
}

pub fn enum_test() {
  assert round_trip(
      sql.insert_mood(value: sql.Happy, nullable_value: Some(sql.Mad)),
      sql.select_mood(),
    )
    == Ok([sql.SelectMood(value: sql.Happy, nullable_value: Some(sql.Mad))])
  assert round_trip(
      sql.insert_mood(value: sql.Sad, nullable_value: None),
      sql.select_mood(),
    )
    == Ok([sql.SelectMood(value: sql.Sad, nullable_value: None)])
}

pub fn slice_test() {
  let db = driver.connect()
  let assert Ok(Nil) =
    list.try_each([1, 2, 3], fn(value) {
      driver.exec(db, sql.insert_slice(value:))
    })

  assert driver.query(db, sql.select_slice(values: [1, 3]))
    == Ok([sql.SelectSlice(1), sql.SelectSlice(3)])
  assert driver.query(db, sql.select_slice(values: [2]))
    == Ok([sql.SelectSlice(2)])
  assert driver.query(db, sql.select_slice(values: [])) == Ok([])
}

// https://github.com/daniellionel01/parrot/issues/74
pub fn keyword_columns_test() {
  assert round_trip(
      sql.insert_keywords(type_: "a", case_: "b"),
      sql.select_keywords(),
    )
    == Ok([sql.SelectKeywords(type_: "a", case_: "b")])
}
