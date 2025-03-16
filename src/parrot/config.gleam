import filepath
import gleam/option.{type Option}
import parrot/internal/project
import simplifile

pub type Driver {
  /// https://github.com/lpil/sqlight
  LpilSqlight
  /// https://github.com/lpil/pog
  LpilPog
  /// https://github.com/VioletBuse/gmysql
  Gmysql
}

pub type Config {
  /// json_file_path: relative to project root directory
  /// gleam_module_out_path: relative to project src directory
  /// driver: support for existing database libraries (mysql, postgresql, sqlite)
  Config(
    json_file_path: String,
    gleam_module_out_path: String,
    driver: Option(Driver),
  )
}

pub fn get_json_file(config: Config) {
  let path = filepath.join(project.root(), config.json_file_path)
  simplifile.read(path)
}

pub fn get_module_directory(config: Config) -> String {
  filepath.join(project.src(), config.gleam_module_out_path)
  |> filepath.directory_name
}

pub fn get_module_path(config: Config) -> String {
  filepath.join(project.src(), config.gleam_module_out_path)
}
