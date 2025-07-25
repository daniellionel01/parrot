import gleam/dynamic/decode
import gleam/float
import gleam/time/calendar.{type Date, type TimeOfDay, Date}
import gleam/time/timestamp.{type Timestamp}

pub type Param {
  ParamInt(Int)
  ParamString(String)
  ParamFloat(Float)
  ParamBool(Bool)
  ParamBitArray(BitArray)
  ParamTimestamp(Timestamp)
  ParamList(List(Param))
  ParamDynamic(decode.Dynamic)
}

pub fn bool_decoder() {
  let int_to_bool = {
    decode.int
    |> decode.then(fn(v) {
      case v {
        0 -> decode.success(False)
        1 -> decode.success(True)
        _ -> decode.failure(False, "could not decode int to boolean")
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

fn datetime_string_decoder() -> decode.Decoder(Timestamp) {
  decode.string
  |> decode.then(fn(datetime_str) {
    case timestamp.parse_rfc3339(datetime_str) {
      Ok(ts) -> decode.success(ts)
      Error(_) ->
        decode.failure(
          timestamp.from_unix_seconds(0),
          "Invalid datetime format",
        )
    }
  })
}

fn datetime_tuple_decoder() -> decode.Decoder(Timestamp) {
  use date <- decode.field(0, date_decoder())
  use time <- decode.field(1, time_decoder())

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
          Error(_) -> decode.failure(calendar.January, "Month")
          Ok(month) -> decode.success(month)
        }
      }),
  )
  use day <- decode.field(2, decode.int)

  decode.success(Date(year:, month:, day:))
}

fn time_decoder() -> decode.Decoder(TimeOfDay) {
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
