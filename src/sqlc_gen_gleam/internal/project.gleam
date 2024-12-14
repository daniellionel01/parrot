//// Copy pasted from https://github.com/giacomocavalieri/squirrel/blob/main/src/squirrel/internal/project.gleam
//// Thank you @giacomocavalieri!
////

import filepath
import simplifile

pub fn root() -> String {
  find_root(".")
}

fn find_root(path: String) -> String {
  let toml = filepath.join(path, "gleam.toml")

  case simplifile.is_file(toml) {
    Ok(False) | Error(_) -> find_root(filepath.join("..", path))
    Ok(True) -> path
  }
}
