import app/sql
import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/result
import pog

pub fn connect() -> pog.Connection {
  let assert Ok(url) = envoy.get("DATABASE_URL")
  let assert Ok(config) = pog.url_config(process.new_name("pog"), url)
  let assert Ok(started) = pog.start(pog.pool_size(config, 1))
  started.data
}

pub fn query(
  db: pog.Connection,
  query: #(String, List(sql.Param), decode.Decoder(a)),
) -> Result(List(a), pog.QueryError) {
  let #(sql, params, decoder) = query
  list.fold(params, pog.query(sql), fn(query, param) {
    pog.parameter(query, to_pog(param))
  })
  |> pog.returning(decoder)
  |> pog.execute(db)
  |> result.map(fn(returned) { returned.rows })
}

pub fn to_pog(param: sql.Param) -> pog.Value {
  case param {
    sql.ParamBool(x) -> pog.bool(x)
    sql.ParamFloat(x) -> pog.float(x)
    sql.ParamInt(x) -> pog.int(x)
    sql.ParamString(x) -> pog.text(x)
    sql.ParamBitArray(x) -> pog.bytea(x)
    sql.ParamList(x) -> pog.array(to_pog, x)
    sql.ParamNullable(x) -> pog.nullable(to_pog, x)
    sql.ParamDate(x) -> pog.calendar_date(x)
    sql.ParamTimestamp(x) -> pog.timestamp(x)
    sql.ParamTimeOfDay(x) -> pog.calendar_time_of_day(x)
    // pog has no encoders for these, so we pass the tuples pg_types expects
    sql.ParamInterval(sql.Interval(months:, days:, microseconds:)) -> {
      let seconds = int.to_float(microseconds) /. 1_000_000.0
      coerce(#(#(0, 0, seconds), days, months))
    }
    sql.ParamInet(sql.Inet(address:, mask:)) ->
      coerce(#(ip_tuple(address), mask))
    sql.ParamMacaddr(<<a, b, c, d, e, f>>) -> coerce(#(a, b, c, d, e, f))
    sql.ParamMacaddr(_) -> panic as "a mac address has 6 bytes"
    sql.ParamDynamic(_) -> panic as "dynamic parameters are not supported"
  }
}

fn ip_tuple(address: BitArray) -> pog.Value {
  case address {
    <<a, b, c, d>> -> coerce(#(a, b, c, d))
    <<a:16, b:16, c:16, d:16, e:16, f:16, g:16, h:16>> ->
      coerce(#(a, b, c, d, e, f, g, h))
    _ -> panic as "an ip address has 4 or 16 bytes"
  }
}

@external(erlang, "gleam_stdlib", "identity")
fn coerce(value: a) -> pog.Value
