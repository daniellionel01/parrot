//// Code that is the same in every generated module: the `Param` type,
//// shared decoders and how the generated code refers to them.

import parrot/internal/codegen/model.{
  type Scalar, GleamBitArray, GleamBool, GleamDate, GleamDynamic, GleamFloat,
  GleamInet, GleamInt, GleamInterval, GleamMacaddr, GleamString, GleamTimeOfDay,
  GleamTimestamp,
}

/// What `code` needs.
pub const imports = [
  "import gleam/dynamic/decode",
  "import gleam/float",
  "import gleam/option",
  "import gleam/time/calendar.{type Date, type TimeOfDay, Date}",
  "import gleam/time/timestamp.{type Timestamp}",
]

/// The gleam type of a scalar, its `Param` constructor and its decoder.
pub type ScalarCode {
  ScalarCode(type_: String, param: String, decoder: String)
}

pub fn scalar(scalar: Scalar) -> ScalarCode {
  case scalar {
    GleamString -> ScalarCode("String", "ParamString", "decode.string")
    GleamInt -> ScalarCode("Int", "ParamInt", "decode.int")
    GleamFloat -> ScalarCode("Float", "ParamFloat", "decode.float")
    GleamBool -> ScalarCode("Bool", "ParamBool", "bool_decoder()")
    GleamTimestamp ->
      ScalarCode("Timestamp", "ParamTimestamp", "datetime_decoder()")
    GleamTimeOfDay ->
      ScalarCode("TimeOfDay", "ParamTimeOfDay", "time_of_day_decoder()")
    GleamDate -> ScalarCode("Date", "ParamDate", "calendar_date_decoder()")
    GleamBitArray -> ScalarCode("BitArray", "ParamBitArray", "decode.bit_array")
    GleamInterval ->
      ScalarCode("Interval", "ParamInterval", "interval_decoder()")
    GleamInet -> ScalarCode("Inet", "ParamInet", "inet_decoder()")
    GleamMacaddr -> ScalarCode("BitArray", "ParamMacaddr", "macaddr_decoder()")
    GleamDynamic ->
      ScalarCode("decode.Dynamic", "ParamDynamic", "decode.dynamic")
  }
}

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
  ParamInterval(Interval)
  ParamInet(Inet)
  ParamMacaddr(BitArray)
  ParamList(List(Param))
  ParamDynamic(decode.Dynamic)
  ParamNullable(option.Option(Param))
}

/// postgres `interval`. Months and days are kept separate, like postgres
/// does, since they have no fixed length.
pub type Interval {
  Interval(months: Int, days: Int, microseconds: Int)
}

/// postgres `inet` and `cidr`. `address` is 4 bytes for ipv4 and 16 bytes
/// for ipv6.
pub type Inet {
  Inet(address: BitArray, mask: Int)
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

/// rfc3339, or without an offset in utc, which is how sqlite's date and
/// time functions write them
fn datetime_string_decoder() -> decode.Decoder(Timestamp) {
  use datetime <- decode.then(decode.string)
  case timestamp.parse_rfc3339(datetime) {
    Ok(ts) -> decode.success(ts)
    Error(_) ->
      case timestamp.parse_rfc3339(datetime <> \"Z\") {
        Ok(ts) -> decode.success(ts)
        Error(_) ->
          decode.failure(
            timestamp.from_unix_seconds(0),
            \"Invalid datetime format\",
          )
      }
  }
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

/// `{interval, {{hours, minutes, seconds}, days, months}}`, how pog returns
/// intervals
pub fn interval_decoder() -> decode.Decoder(Interval) {
  use #(time, days, months) <- decode.field(1, {
    use time <- decode.field(0, time_of_day_tuple_decoder())
    use days <- decode.field(1, decode.int)
    use months <- decode.field(2, decode.int)
    decode.success(#(time, days, months))
  })
  let seconds = { time.hours * 60 + time.minutes } * 60 + time.seconds
  let microseconds = seconds * 1_000_000 + time.nanoseconds / 1000
  decode.success(Interval(months:, days:, microseconds:))
}

/// `{address, mask}`, or only `address` for a single host
pub fn inet_decoder() -> decode.Decoder(Inet) {
  let with_mask = {
    use address <- decode.field(0, ip_address_decoder())
    use mask <- decode.field(1, decode.int)
    decode.success(Inet(address:, mask:))
  }
  let host = {
    use address <- decode.map(ip_address_decoder())
    case address {
      <<_:32>> -> Inet(address:, mask: 32)
      _ -> Inet(address:, mask: 128)
    }
  }
  decode.one_of(with_mask, [host])
}

/// ipv4 as a tuple of 4 bytes, ipv6 as a tuple of 8 16-bit groups
fn ip_address_decoder() -> decode.Decoder(BitArray) {
  let ipv6 = {
    use a <- decode.field(0, decode.int)
    use b <- decode.field(1, decode.int)
    use c <- decode.field(2, decode.int)
    use d <- decode.field(3, decode.int)
    use e <- decode.field(4, decode.int)
    use f <- decode.field(5, decode.int)
    use g <- decode.field(6, decode.int)
    use h <- decode.field(7, decode.int)
    decode.success(<<a:16, b:16, c:16, d:16, e:16, f:16, g:16, h:16>>)
  }
  let ipv4 = {
    use a <- decode.field(0, decode.int)
    use b <- decode.field(1, decode.int)
    use c <- decode.field(2, decode.int)
    use d <- decode.field(3, decode.int)
    decode.success(<<a, b, c, d>>)
  }
  decode.one_of(ipv6, [ipv4])
}

/// a tuple of 6 bytes
pub fn macaddr_decoder() -> decode.Decoder(BitArray) {
  use a <- decode.field(0, decode.int)
  use b <- decode.field(1, decode.int)
  use c <- decode.field(2, decode.int)
  use d <- decode.field(3, decode.int)
  use e <- decode.field(4, decode.int)
  use f <- decode.field(5, decode.int)
  decode.success(<<a, b, c, d, e, f>>)
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
