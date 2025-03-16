//// Copy pasted from https://github.com/giacomocavalieri/squirrel/blob/main/src/squirrel/internal/project.gleam
//// Thank you https://www.github.com/giacomocavalieri
////

import filepath
import parrot/internal/lib
import simplifile
import tom

pub fn version() -> Result(String, Nil) {
  let configuration_path = filepath.join(root(), "gleam.toml")

  use configuration <- lib.try_nil(simplifile.read(configuration_path))
  use toml <- lib.try_nil(tom.parse(configuration))
  use name <- lib.try_nil(tom.get_string(toml, ["version"]))
  Ok(name)
}

pub fn root() -> String {
  find_root(".")
}

pub fn src() -> String {
  filepath.join(root(), "src")
}

fn find_root(path: String) -> String {
  let toml = filepath.join(path, "gleam.toml")

  case simplifile.is_file(toml) {
    Ok(False) | Error(_) -> find_root(filepath.join("..", path))
    Ok(True) -> path
  }
}
