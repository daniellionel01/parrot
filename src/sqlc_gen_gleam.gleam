import gleam/dynamic as d
import gleam/io
import gleam/json
import simplifile
import sqlc_gen_gleam/config.{
  type Config, Config, get_json_file, get_module_directory, get_module_path,
}
import sqlc_gen_gleam/internal/generate
import sqlc_gen_gleam/internal/lib
import sqlc_gen_gleam/internal/sqlc

pub fn main() {
  mysql()
  // psql()
  // sqlite()
}

pub fn mysql() {
  Config(
    json_file_path: "sql/mysql/gen/codegen.json",
    gleam_module_out_path: "gen/sqlc_mysql.gleam",
  )
  |> run()
}

pub fn psql() {
  Config(
    json_file_path: "sql/psql/gen/codegen.json",
    gleam_module_out_path: "gen/sqlc_psql.gleam",
  )
  |> run()
}

pub fn sqlite() {
  Config(
    json_file_path: "sql/sqlite/gen/codegen.json",
    gleam_module_out_path: "gen/sqlc_sqlite.gleam",
  )
  |> run()
}

pub fn run(config: Config) {
  use json_string <- lib.try_nil(get_json_file(config))

  use dyn_json <- lib.try_nil(json.decode(from: json_string, using: d.dynamic))

  let parsed = sqlc.decode_sqlc(dyn_json)
  let _ = io.debug(parsed)

  let _ =
    get_module_directory(config)
    |> simplifile.create_directory_all()
  let _ =
    simplifile.write(
      to: get_module_path(config),
      contents: generate.comment_dont_edit(),
    )
    |> io.debug

  Ok(Nil)
}
