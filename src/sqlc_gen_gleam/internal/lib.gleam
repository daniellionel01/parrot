//// Various gleam code utilities
////

import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub fn try_nil(
  result: Result(a, b),
  then do: fn(a) -> Result(c, Nil),
) -> Result(c, Nil) {
  result.try(result.replace_error(result, Nil), do)
}

/// Thank you https://github.com/MystPi/dedent/blob/main/src/dedent.gleam!
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
