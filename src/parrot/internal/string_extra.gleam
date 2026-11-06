//// Thank you https://github.com/lpil/justin
////

import gleam/list
import gleam/string

/// Convert a string to a `snake_case`.
///
/// # Examples
///
/// ```gleam
/// snake_case("Hello World")
/// // -> "hello_world"
/// ```
///
pub fn snake_case(text: String) -> String {
  text
  |> split_words
  |> string.join("_")
  |> string.lowercase
}

/// Convert a string to a `PascalCase`.
///
/// # Examples
///
/// ```gleam
/// pascal_case("Hello World")
/// // -> "HelloWorld"
/// ```
///
pub fn pascal_case(text: String) -> String {
  text
  |> split_words
  |> list.map(string.capitalise)
  |> string.concat
}

fn split_words(text: String) -> List(String) {
  text
  |> string.to_graphemes
  |> split(False, "", [])
}

fn split(
  graphemes: List(String),
  in_uppercase: Bool,
  word: String,
  words: List(String),
) -> List(String) {
  case graphemes {
    [] if word == "" -> list.reverse(words)
    [] -> list.reverse(add(words, word))

    ["\n", ..graphemes]
    | ["\t", ..graphemes]
    | ["!", ..graphemes]
    | ["?", ..graphemes]
    | ["#", ..graphemes]
    | [".", ..graphemes]
    | ["-", ..graphemes]
    | ["_", ..graphemes]
    | [" ", ..graphemes] -> split(graphemes, False, "", add(words, word))

    [grapheme, ..graphemes] -> {
      case is_upper(grapheme) {
        False -> split(graphemes, False, word <> grapheme, words)

        True if in_uppercase ->
          split(graphemes, in_uppercase, word <> grapheme, words)

        True -> split(graphemes, True, grapheme, add(words, word))
      }
    }
  }
}

fn add(words: List(String), word: String) -> List(String) {
  case word {
    "" -> words
    _ -> [word, ..words]
  }
}

fn is_upper(grapheme: String) -> Bool {
  string.lowercase(grapheme) != grapheme
}
