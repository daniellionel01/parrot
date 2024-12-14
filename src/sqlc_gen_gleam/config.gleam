import filepath
import simplifile
import sqlc_gen_gleam/internal/project

pub type Config {
  /// json_file_path - relative to project root directory
  Config(json_file_path: String)
}

pub fn get_json_file(config: Config) {
  let path = filepath.join(project.root(), config.json_file_path)
  simplifile.read(path)
}
