//// Copy pasted from https://github.com/giacomocavalieri/squirrel/blob/main/src/squirrel/internal/project.gleam
//// Thank you https://www.github.com/giacomocavalieri
////

import filepath
import simplifile
import tom

pub fn root() -> String {
  find_root(".")
}

pub fn src() -> String {
  filepath.join(root(), "src")
}

pub fn project_name() -> String {
  let root = find_root(".")
  let toml_path = filepath.join(root, "gleam.toml")
  let assert Ok(toml) = simplifile.read(toml_path)

  let assert Ok(parsed) = tom.parse(toml)
  let assert Ok(name) = tom.get_string(parsed, ["name"])

  name
}

fn find_root(path: String) -> String {
  let toml = filepath.join(path, "gleam.toml")

  case simplifile.is_file(toml) {
    Ok(False) | Error(_) -> find_root(filepath.join("..", path))
    Ok(True) -> path
  }
}
