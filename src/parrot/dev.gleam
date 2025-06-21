import gleam/dynamic/decode
import gleam/time/timestamp.{type Timestamp}
import parrot/internal/decoder

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

pub fn datetime_decoder() -> decode.Decoder(Timestamp) {
  decode.one_of(decoder.datetime_string_decoder(), or: [
    decoder.datetime_tuple_decoder(),
  ])
}
