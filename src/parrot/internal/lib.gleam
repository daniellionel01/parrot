//// Various gleam code utilities
////

import filepath
import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import simplifile

pub fn try_nil(
  result: Result(a, b),
  then do: fn(a) -> Result(c, Nil),
) -> Result(c, Nil) {
  result.try(result.replace_error(result, Nil), do)
}

/// Thank you https://github.com/MystPi/dedent/blob/main/src/dedent.gleam
pub fn dedent(text: String) -> String {
  let lines =
    text
    |> string.split("\n")

  let min_indent =
    lines
    |> list.filter(fn(line) { !is_all_whitespace(line) })
    |> list.map(indent_size(_, 0))
    |> list.sort(int.compare)
    |> list.first
    |> result.unwrap(0)

  lines
  |> list.map(string.drop_start(_, min_indent))
  |> string.join("\n")
  |> string.trim
}

fn indent_size(text: String, size: Int) -> Int {
  case text {
    " " <> rest | "\t" <> rest -> indent_size(rest, size + 1)
    _ -> size
  }
}

fn is_all_whitespace(text: String) -> Bool {
  text
  |> string.trim
  |> string.is_empty
}

/// Finds all `from/**/sql` directories and lists the full paths of the `*.sql`
/// files inside each one.
/// https://github.com/giacomocavalieri/squirrel/blob/main/src/squirrel.gleam
///
pub fn walk(from: String) -> Dict(String, List(String)) {
  case filepath.base_name(from) {
    "sql" -> {
      let assert Ok(files) = simplifile.read_directory(from)
      let files = {
        use file <- list.filter_map(files)
        use extension <- result.try(filepath.extension(file))
        use <- bool.guard(when: extension != "sql", return: Error(Nil))
        let file_name = filepath.join(from, file)
        case simplifile.is_file(file_name) {
          Ok(True) -> Ok(file_name)
          Ok(False) | Error(_) -> Error(Nil)
        }
      }
      dict.from_list([#(from, files)])
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

      list.map(directories, walk)
      |> list.fold(from: dict.new(), with: dict.merge)
    }
  }
}
