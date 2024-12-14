//// Various gleam code utilities
////

import gleam/result

pub fn try_nil(
  result: Result(a, b),
  then do: fn(a) -> Result(c, Nil),
) -> Result(c, Nil) {
  result.try(result.replace_error(result, Nil), do)
}
