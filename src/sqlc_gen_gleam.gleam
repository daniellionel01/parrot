import gleam/io
import sqlc_gen_gleam/config.{Config, get_json_file}

pub fn main() {
  let config = Config(json_file_path: "sql/gen/codegen.json")

  let codegen = get_json_file(config)

  io.debug(codegen)
}
