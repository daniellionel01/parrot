//// Various gleam code utilities
////

import filepath
import gleam/bool
import gleam/list
import gleam/result
import simplifile

pub const colorless = "\u{001b}[0m"

pub fn try_nil(
  result: Result(a, b),
  then do: fn(a) -> Result(c, Nil),
) -> Result(c, Nil) {
  result.try(result.replace_error(result, Nil), do)
}

/// Finds all `from/**/sql` directories and lists the full paths of the `*.sql`
/// files inside each one.
/// https://github.com/giacomocavalieri/squirrel/blob/main/src/squirrel.gleam
///
pub fn walk(from: String) -> Result(List(String), Nil) {
  use expanded <- result.try(filepath.expand(from))
  Ok(walk_recur(expanded))
}

fn walk_recur(from: String) -> List(String) {
  case filepath.base_name(from) {
    "sql" -> {
      let assert Ok(files) = simplifile.read_directory(from)
      use file <- list.filter_map(files)
      use extension <- result.try(filepath.extension(file))
      use <- bool.guard(when: extension != "sql", return: Error(Nil))
      let file_name = filepath.join(from, file)
      case simplifile.is_file(file_name) {
        Ok(True) -> Ok(file_name)
        Ok(False) | Error(_) -> Error(Nil)
      }
    }

    _ -> {
      let assert Ok(files) = simplifile.read_directory(from)
      let directories = {
        use file <- list.filter_map(files)
        let file_name = filepath.join(from, file)
        case simplifile.is_directory(file_name) {
          Ok(True) -> Ok(file_name)
          Ok(False) | Error(_) -> Error(Nil)
        }
      }
      list.flat_map(directories, walk_recur)
    }
  }
}

pub fn green(text: String) {
  "\u{001b}[32m" <> text <> colorless
}

pub fn red(text: String) {
  "\u{001b}[31m" <> text <> colorless
}

pub fn yellow(text: String) {
  "\u{001b}[33m" <> text <> colorless
}
