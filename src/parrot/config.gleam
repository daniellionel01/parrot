import filepath
import parrot/internal/project
import simplifile

pub type Config {
  Config(
    /// relative to project root directory
    json_file_path: String,
    /// relative to project src directory
    gleam_module_out_path: String,
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
