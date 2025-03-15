import gleam/option
import sqlc_gen_gleam/codegen
import sqlc_gen_gleam/config

pub fn main() {
  let config =
    config.Config(
      driver: option.None,
      gleam_module_out_path: "gen/sql.gleam",
      json_file_path: "sql/psql/gen/codegen.json",
    )
  codegen.codegen_from_config(config)
}
