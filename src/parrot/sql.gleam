import gleam/dynamic/decode
import gleam/time/timestamp.{type Timestamp}

pub type Param {
  ParamInt(Int)
  ParamString(String)
  ParamFloat(Float)
  ParamBool(Bool)
  ParamTimestamp(Timestamp)
}

pub fn datetime_decoder() -> decode.Decoder(Timestamp) {
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
