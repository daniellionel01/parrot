import gleam/dynamic as d
import gleam/io
import gleam/json
import sqlc_gen_gleam/config.{Config, get_json_file}
import sqlc_gen_gleam/internal/lib
import sqlc_gen_gleam/internal/sqlc

pub fn main() {
  let config = Config(json_file_path: "sql/mysql/gen/codegen.json")
  // let config = Config(json_file_path: "sql/psql/gen/codegen.json")
  // let config = Config(json_file_path: "sql/sqlite/gen/codegen.json")

  use json_string <- lib.try_nil(get_json_file(config))

  use unknown_json <- lib.try_nil(json.decode(
    from: json_string,
    using: d.dynamic,
  ))

  let _ =
    sqlc.decode_sqlc(unknown_json)
    |> io.debug

  Ok(Nil)
}
