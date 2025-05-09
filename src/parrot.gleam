import argv
import gleam/io
import parrot/codegen
import parrot/config

const usage = "Usage:
  gleam run -m parrot gen [--out MODULE_PATH]
  gleam run -m parrot help
"

pub fn main() {
  case argv.load().arguments {
    ["gen"] -> todo
    ["help"] -> io.println(usage)
    _ -> io.println(usage)
  }

  let config =
    config.Config(
      gleam_module_out_path: "gen/sql.gleam",
      json_file_path: "integration_tests/mysql/gen/codegen.json",
    )
  codegen.codegen_from_config(config)
}
