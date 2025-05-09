import gleam/option
import parrot/codegen
import parrot/config

pub fn main() {
  let config =
    config.Config(
      driver: option.None,
      gleam_module_out_path: "gen/sql.gleam",
      json_file_path: "integration_tests/mysql/gen/codegen.json",
    )
  codegen.codegen_from_config(config)
}
