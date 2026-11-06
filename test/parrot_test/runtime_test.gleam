import gleam/list
import gleam/string
import parrot/internal/codegen/runtime

/// Generated definitions are checked against `runtime.types` and
/// `runtime.values`, so these have to include every name the runtime code
/// and its imports define.
pub fn runtime_types_are_reserved_test() {
  let #(types, _) = runtime_definitions()
  assert list.filter(types, fn(name) { !list.contains(runtime.types, name) })
    == []
}

pub fn runtime_values_are_reserved_test() {
  let #(_, values) = runtime_definitions()
  assert list.filter(values, fn(name) { !list.contains(runtime.values, name) })
    == []
}

/// The types and the constructors and functions of `runtime.code` and
/// `runtime.imports`.
fn runtime_definitions() -> #(List(String), List(String)) {
  let #(types, values, _) =
    runtime.code
    |> string.split("\n")
    |> list.fold(#([], [], False), fn(acc, line) {
      let #(types, values, in_type) = acc
      case line {
        "pub type " <> rest -> #([name(rest, " "), ..types], values, True)
        "}" -> #(types, values, False)
        "pub fn " <> rest | "fn " <> rest -> #(
          types,
          [name(rest, "("), ..values],
          in_type,
        )
        "  " <> rest if in_type -> #(types, [name(rest, "("), ..values], True)
        _ -> acc
      }
    })

  let imported =
    list.flat_map(runtime.imports, fn(line) {
      case string.split_once(line, "{") {
        Ok(#(_, rest)) -> string.split(name(rest, "}"), ", ")
        Error(_) -> []
      }
    })
  let imported_types =
    list.filter_map(imported, fn(item) {
      case item {
        "type " <> name -> Ok(name)
        _ -> Error(Nil)
      }
    })
  let imported_values =
    list.filter(imported, fn(item) { !string.starts_with(item, "type ") })

  #(list.append(types, imported_types), list.append(values, imported_values))
}

/// The text before `end`.
fn name(text: String, end: String) -> String {
  case string.split_once(text, end) {
    Ok(#(name, _)) -> name
    Error(_) -> text
  }
}
