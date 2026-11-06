import app/driver
import app/sql
import gleam/list
import gleam/option.{None, Some}
import gleam/time/calendar
import gleam/time/duration
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
  assert query(sql.integer_round_trip(1, Some(2)))
    == Ok([sql.IntegerRoundTrip(1, Some(2))])
}

pub fn float_test() {
  assert query(sql.real_round_trip(1.5, Some(2.5)))
    == Ok([sql.RealRoundTrip(1.5, Some(2.5))])
  assert query(sql.numeric_round_trip(1.5, Some(2.5)))
    == Ok([sql.NumericRoundTrip(1.5, Some(2.5))])
}

pub fn string_test() {
  assert query(sql.text_round_trip("a", Some("b")))
    == Ok([sql.TextRoundTrip("a", Some("b"))])
  assert query(sql.varchar_round_trip("a", Some("b")))
    == Ok([sql.VarcharRoundTrip("a", Some("b"))])
}

pub fn bool_test() {
  assert query(sql.boolean_round_trip(True, Some(False)))
    == Ok([sql.BooleanRoundTrip(True, Some(False))])
}

pub fn blob_test() {
  assert query(sql.blob_round_trip(<<1, 2>>, Some(<<3>>)))
    == Ok([sql.BlobRoundTrip(<<1, 2>>, Some(<<3>>))])
}

pub fn time_test() {
  let date = calendar.Date(2024, calendar.March, 1)
  assert query(sql.date_round_trip(date, Some(date)))
    == Ok([sql.DateRoundTrip(date, Some(date))])

  let ts = timestamp.from_unix_seconds(1_700_000_000)
  assert query(sql.datetime_round_trip(ts, Some(ts)))
    == Ok([sql.DatetimeRoundTrip(ts, Some(ts))])
  // sqlite's own date and time functions write utc without an offset
  let assert Ok(written) = timestamp.parse_rfc3339("2024-03-01T12:30:00Z")
  let fraction = timestamp.add(written, duration.milliseconds(250))
  assert query(sql.sqlite_written_datetime())
    == Ok([sql.SqliteWrittenDatetime(written, Some(fraction))])
  assert query(sql.timestamp_round_trip(ts, Some(ts)))
    == Ok([sql.TimestampRoundTrip(ts, Some(ts))])

  let time = calendar.TimeOfDay(12, 30, 0, 0)
  assert query(sql.time_round_trip(time, Some(time)))
    == Ok([sql.TimeRoundTrip(time, Some(time))])
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

pub fn slice_between_named_params_test() {
  let db = driver.connect()
  let assert Ok(Nil) =
    list.try_each([10, 20, 30], fn(value) {
      driver.exec(db, sql.insert_slice(value:))
    })

  assert driver.query(
      db,
      sql.select_slice_between(min: 10, values: [10, 20, 30], max: 25),
    )
    == Ok([sql.SelectSliceBetween(10), sql.SelectSliceBetween(20)])
}

// https://github.com/daniellionel01/parrot/issues/74
pub fn keyword_columns_test() {
  assert query(sql.keywords_round_trip(type_: "a", case_: "b"))
    == Ok([sql.KeywordsRoundTrip(type_: "a", case_: "b")])
}

/// Parameters and columns named like what parrot generates.
pub fn name_collisions_test() {
  let db = driver.connect()
  let assert Ok(Nil) =
    driver.exec(
      db,
      sql.insert_name_collision(
        sql: "a",
        ids_slice: 1,
        bool_decoder: 2,
        active: True,
      ),
    )
  let assert Ok(Nil) =
    driver.exec(
      db,
      sql.insert_name_collision(
        sql: "b",
        ids_slice: 1,
        bool_decoder: 2,
        active: True,
      ),
    )

  assert driver.query(
      db,
      sql.name_collisions(
        sql: "a",
        ids_slice: 1,
        ids: [2],
        name_collisions_decoder: True,
      ),
    )
    == Ok([
      sql.NameCollisions(bool_decoder: 2, active: True, count: 1, count_2: 1),
    ])

  // `?<number>` params after a slice with more than one item
  assert driver.query(
      db,
      sql.name_collisions(
        sql: "a",
        ids_slice: 1,
        ids: [2, 3],
        name_collisions_decoder: True,
      ),
    )
    == Ok([
      sql.NameCollisions(bool_decoder: 2, active: True, count: 1, count_2: 1),
    ])

  assert driver.query(db, sql.duplicate_parameters(sql: "a", sql_2: "b"))
    == Ok([sql.DuplicateParameters(2), sql.DuplicateParameters(2)])
}
