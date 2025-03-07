import gleam/io
import sqlc_gen_gleam/internal/string_case

pub fn main() {
  string_case.snake_case("HelloWorld")
  |> io.println

  string_case.pascal_case("HelloWorld")
  |> io.println
}
