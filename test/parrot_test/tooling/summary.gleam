//// Compact rendering of what parrot reads from sqlc's JSON, for snapshots.
//// The raw JSON includes all of `pg_catalog`.

import gleam/int
import gleam/list
import gleam/option
import gleam/string
import parrot/internal/sqlc

const system_schemas = ["pg_catalog", "pg_temp", "information_schema"]

pub fn render(output: sqlc.Output) -> String {
  let catalog = output.catalog
  let schemas =
    list.filter(catalog.schemas, fn(schema) {
      !list.contains(system_schemas, schema.name)
    })

  let enums =
    list.flat_map(schemas, fn(schema) {
      list.map(schema.enums, render_enum(_, schema.name, catalog.default_schema))
    })
  let queries = list.map(output.queries, render_query)

  [enums, queries]
  |> list.flatten
  |> string.join("\n\n")
}

fn render_enum(
  enum: sqlc.Enum,
  schema: String,
  default_schema: String,
) -> String {
  "enum "
  <> qualified(schema, enum.name, default_schema)
  <> "\n  "
  <> string.join(enum.vals, " | ")
}

fn render_query(query: sqlc.Query) -> String {
  let params = case query.params {
    [] -> ["  params: none"]
    params -> [
      "  params:",
      ..list.map(params, fn(param) {
        "    $"
        <> int.to_string(param.number)
        <> " "
        <> render_column(param.column)
      })
    ]
  }
  let columns = case query.columns {
    [] -> ["  columns: none"]
    columns -> [
      "  columns:",
      ..list.map(columns, fn(col) { "    " <> render_column(col) })
    ]
  }

  ["query " <> query.name <> " " <> query.cmd]
  |> list.append(params)
  |> list.append(columns)
  |> string.join("\n")
}

fn render_column(col: sqlc.Column) -> String {
  let table = case col.table {
    option.Some(table) if table != "" -> table <> "."
    _ -> ""
  }
  let name = case col.name {
    "" -> "<unnamed>"
    name -> name
  }
  let array = case col.is_array {
    False -> ""
    True -> "[]"
  }
  let flags =
    [
      case col.not_null {
        True -> option.Some("not null")
        False -> option.Some("null")
      },
      case col.is_sqlc_slice {
        True -> option.Some("slice")
        False -> option.None
      },
    ]
    |> option.values

  table
  <> name
  <> ": "
  <> col.type_ref.name
  <> array
  <> " ("
  <> string.join(flags, ", ")
  <> ")"
}

fn qualified(schema: String, name: String, default_schema: String) -> String {
  case schema {
    "" -> name
    schema if schema == default_schema -> name
    schema -> schema <> "." <> name
  }
}
