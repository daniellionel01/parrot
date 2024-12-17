import filepath
import simplifile
import sqlc_gen_gleam/internal/project

pub type Config {
  /// json_file_path: relative to project root directory
  /// gleam_module_out_path: relative to project src directory
  Config(json_file_path: String, gleam_module_out_path: String)
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
