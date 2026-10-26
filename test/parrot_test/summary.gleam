//// A compact, human readable rendering of the JSON that sqlc generates.
////
//// The raw JSON is not suitable for snapshots: for postgres it contains the
//// entire `pg_catalog` and `information_schema` (tens of thousands of lines
//// even for a single table). This only renders what parrot actually reads:
//// the user defined tables and enums, and every query with its parameters
//// and columns.
////

import gleam/int
import gleam/list
import gleam/option
import gleam/string
import parrot/internal/sqlc

const system_schemas = ["pg_catalog", "pg_temp", "information_schema"]

pub fn render(context: sqlc.SQLC) -> String {
  let catalog = context.catalog
  let schemas =
    list.filter(catalog.schemas, fn(schema) {
      !list.contains(system_schemas, schema.name)
    })

  let tables =
    list.flat_map(schemas, fn(schema) {
      list.map(schema.tables, render_table(_, catalog.default_schema))
    })
  let enums =
    list.flat_map(schemas, fn(schema) {
      list.map(schema.enums, render_enum(_, schema.name, catalog.default_schema))
    })
  let queries = list.map(context.queries, render_query)

  [tables, enums, queries]
  |> list.flatten
  |> string.join("\n\n")
}

fn render_table(table: sqlc.Table, default_schema: String) -> String {
  let name = qualified(table.rel.schema, table.rel.name, default_schema)
  let columns = list.map(table.columns, fn(col) { "  " <> render_column(col) })
  string.join(["table " <> name, ..columns], "\n")
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

  ["query " <> query.name <> " :" <> sqlc.query_cmd_to_string(query.cmd)]
  |> list.append(params)
  |> list.append(columns)
  |> string.join("\n")
}

fn render_column(col: sqlc.TableColumn) -> String {
  let table = case col.table {
    option.Some(table) if table.name != "" -> table.name <> "."
    _ -> ""
  }
  let name = case col.name {
    "" -> "<unnamed>"
    name -> name
  }
  let array = case col.is_array, col.array_dims {
    False, _ -> ""
    True, dims -> string.repeat("[]", int.max(dims, 1))
  }
  let flags =
    [
      case col.not_null {
        True -> option.Some("not null")
        False -> option.Some("null")
      },
      case col.unsigned {
        True -> option.Some("unsigned")
        False -> option.None
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
