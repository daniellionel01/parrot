//// Code that is the same in every generated module: the `Param` type and
//// shared decoders.

pub const code =
  "
pub type Param {
  ParamInt(Int)
  ParamString(String)
  ParamFloat(Float)
  ParamBool(Bool)
  ParamBitArray(BitArray)
  ParamTimestamp(Timestamp)
  ParamTimeOfDay(TimeOfDay)
  ParamDate(Date)
  ParamList(List(Param))
  ParamDynamic(decode.Dynamic)
  ParamNullable(option.Option(Param))
}

pub fn bool_decoder() {
  let int_to_bool = {
    decode.int
    |> decode.then(fn(v) {
      case v {
        0 -> decode.success(False)
        1 -> decode.success(True)
        _ -> decode.failure(False, \"could not decode int to boolean\")
      }
    })
  }
  decode.one_of(decode.bool, or: [int_to_bool])
}

pub fn datetime_decoder() -> decode.Decoder(Timestamp) {
  decode.one_of(datetime_string_decoder(), or: [
    datetime_tuple_decoder(),
    timestamp_decoder(),
  ])
}

/// https://github.com/lpil/pog/blob/v4.1.0/src/pog.gleam#L394
fn timestamp_decoder() -> decode.Decoder(Timestamp) {
  use microseconds <- decode.map(decode.int)
  let seconds = microseconds / 1_000_000
  let nanoseconds = { microseconds % 1_000_000 } * 1000
  timestamp.from_unix_seconds_and_nanoseconds(seconds, nanoseconds)
}

/// https://github.com/lpil/pog/blob/v4.1.0/src/pog.gleam#L873
pub fn calendar_date_decoder() -> decode.Decoder(Date) {
  decode.one_of(date_decoder(), or: [date_string_decoder()])
}

/// `YYYY-MM-DD`, f.e. how sqlite stores dates
fn date_string_decoder() -> decode.Decoder(Date) {
  use date <- decode.then(decode.string)
  case timestamp.parse_rfc3339(date <> \"T00:00:00Z\") {
    Ok(ts) -> decode.success(timestamp.to_calendar(ts, calendar.utc_offset).0)
    Error(_) ->
      decode.failure(calendar.Date(0, calendar.January, 1), \"Calendar date\")
  }
}

fn datetime_string_decoder() -> decode.Decoder(Timestamp) {
  decode.string
  |> decode.then(fn(datetime_str) {
    case timestamp.parse_rfc3339(datetime_str) {
      Ok(ts) -> decode.success(ts)
      Error(_) ->
        decode.failure(
          timestamp.from_unix_seconds(0),
          \"Invalid datetime format\",
        )
    }
  })
}

fn datetime_tuple_decoder() -> decode.Decoder(Timestamp) {
  use date <- decode.field(0, date_decoder())
  use time <- decode.field(1, time_of_day_tuple_decoder())

  timestamp.from_calendar(date:, time:, offset: calendar.utc_offset)
  |> decode.success()
}

fn date_decoder() -> decode.Decoder(Date) {
  use year <- decode.field(0, decode.int)
  use month <- decode.field(
    1,
    decode.int
      |> decode.then(fn(month) {
        case calendar.month_from_int(month) {
          Error(_) -> decode.failure(calendar.January, \"Month\")
          Ok(month) -> decode.success(month)
        }
      }),
  )
  use day <- decode.field(2, decode.int)

  decode.success(Date(year:, month:, day:))
}

pub fn time_of_day_decoder() -> decode.Decoder(TimeOfDay) {
  decode.one_of(time_of_day_tuple_decoder(), or: [
    time_of_day_string_decoder(),
    time_of_day_with_days_decoder(),
  ])
}

/// `HH:MM:SS[.fraction]`, f.e. how sqlite stores times
fn time_of_day_string_decoder() -> decode.Decoder(TimeOfDay) {
  use time <- decode.then(decode.string)
  case timestamp.parse_rfc3339(\"1970-01-01T\" <> time <> \"Z\") {
    Ok(ts) -> decode.success(timestamp.to_calendar(ts, calendar.utc_offset).1)
    Error(_) -> decode.failure(calendar.TimeOfDay(0, 0, 0, 0), \"Time of day\")
  }
}

/// `{days, {hours, minutes, seconds}}`, how mysql returns times
fn time_of_day_with_days_decoder() -> decode.Decoder(TimeOfDay) {
  use days <- decode.field(0, decode.int)
  use time <- decode.field(1, time_of_day_tuple_decoder())
  case days {
    0 -> decode.success(time)
    _ -> decode.failure(time, \"Time of day\")
  }
}

fn time_of_day_tuple_decoder() -> decode.Decoder(TimeOfDay) {
  use hours <- decode.field(0, decode.int)
  use minutes <- decode.field(1, decode.int)
  use #(seconds, nanoseconds) <- decode.field(2, seconds_decoder())

  calendar.TimeOfDay(hours:, minutes:, seconds:, nanoseconds:)
  |> decode.success()
}

fn seconds_decoder() -> decode.Decoder(#(Int, Int)) {
  let int = {
    decode.int
    |> decode.map(fn(i) { #(i, 0) })
  }
  let float = {
    decode.float
    |> decode.map(fn(f) {
      let floored = float.floor(f)
      let seconds = float.round(floored)
      let nanoseconds = float.round({ f -. floored } *. 1_000_000_000.0)
      #(seconds, nanoseconds)
    })
  }
  decode.one_of(int, [float])
}
"
