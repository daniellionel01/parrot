//// Configuration for a gleam project which is
//// gathered from command line arguments and the
//// `[tools.parrot]` configuration in `gleam.toml`.
////

import filepath
import parrot/error
import parrot/internal/project
import simplifile

/// All file paths are relative to the project's root.
///
pub opaque type Config {
  Config(
    json_file_path: String,
    output_module_path: String,
    sqlc_binary: String,
    sqlc_version: String,
    sqlc_schema: String,
  )
}

/// Loads the config from gleam.toml and cli args
///
pub fn load(queries_file: String) -> Result(Config, error.ParrotError) {
  let project_name = project.name()
  let output_module_path = "src/" <> project_name <> "/sql.gleam"

  let config =
    Config(
      json_file_path: queries_file,
      output_module_path:,
      sqlc_binary: todo,
      sqlc_version: todo,
      sqlc_schema: todo,
    )
  Ok(config)
}

pub fn json_file(config: Config) -> Result(String, simplifile.FileError) {
  let path = filepath.join(project.root(), config.json_file_path)
  simplifile.read(path)
}

pub fn output_module_path(config: Config) -> String {
  filepath.join(project.root(), config.output_module_path)
}

pub fn output_directory(config: Config) -> String {
  output_module_path(config)
  |> filepath.directory_name
}
