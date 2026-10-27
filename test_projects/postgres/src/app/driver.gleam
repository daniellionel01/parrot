import app/sql
import envoy
import gleam/dynamic/decode
import gleam/erlang/process
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
    sql.ParamDynamic(_) -> panic as "dynamic parameters are not supported"
  }
}
