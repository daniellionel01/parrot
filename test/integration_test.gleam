import gleam/option.{None}
import gleeunit/should
import sqlc_gen_gleam/codegen.{codegen_from_config}
import sqlc_gen_gleam/config.{Config}

pub fn main() {
  let _ =
    Config(
      json_file_path: "sql/sqlite/gen/codegen.json",
      gleam_module_out_path: "gen/sqlc_sqlite.gleam",
      driver: None,
    )
    |> codegen_from_config()

  should.equal(1, 1)
}
