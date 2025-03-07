//// Thank you https://github.com/lpil/justin

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

/// Convert a string to a `camelCase`.
///
/// # Examples
///
/// ```gleam
/// camel_case("Hello World")
/// // -> "helloWorld"
/// ```
///
pub fn camel_case(text: String) -> String {
  text
  |> split_words
  |> list.index_map(fn(word, i) {
    case i {
      0 -> string.lowercase(word)
      _ -> string.capitalise(word)
    }
  })
  |> string.concat
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

/// Convert a string to a `kebab-case`.
///
/// # Examples
///
/// ```gleam
/// kabab_case("Hello World")
/// // -> "hello-world
/// ```
///
pub fn kebab_case(text: String) -> String {
  text
  |> split_words
  |> string.join("-")
  |> string.lowercase
}

/// Convert a string to a `Sentence case`.
///
/// # Examples
///
/// ```gleam
/// sentence_case("hello-world")
/// // -> "Hello world
/// ```
///
pub fn sentence_case(text: String) -> String {
  text
  |> split_words
  |> string.join(" ")
  |> string.capitalise
}

fn split_words(text: String) -> List(String) {
  text
  |> string.to_graphemes
  |> split(False, "", [])
}

fn split(
  in: List(String),
  up: Bool,
  word: String,
  words: List(String),
) -> List(String) {
  case in {
    [] if word == "" -> list.reverse(words)
    [] -> list.reverse(add(words, word))

    ["\n", ..in]
    | ["\t", ..in]
    | ["!", ..in]
    | ["?", ..in]
    | ["#", ..in]
    | [".", ..in]
    | ["-", ..in]
    | ["_", ..in]
    | [" ", ..in] -> split(in, False, "", add(words, word))

    [g, ..in] -> {
      case is_upper(g) {
        // Lowercase, not a new word
        False -> split(in, False, word <> g, words)

        // Uppercase and inside an uppercase word, not a new word
        True if up -> split(in, up, word <> g, words)

        // Uppercase otherwise, a new word
        True -> split(in, True, g, add(words, word))
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

fn is_upper(g: String) -> Bool {
  string.lowercase(g) != g
}
