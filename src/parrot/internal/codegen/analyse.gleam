//// Turns the output of sqlc into a `model.Module`. Every check that can fail
//// happens here, printing the module can not fail.

import gleam/bool
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import parrot/error.{type ParrotError}
import parrot/internal/codegen/model.{
  type GleamType, type Query, Field, GleamBitArray, GleamBool, GleamDate,
  GleamDynamic, GleamEnum, GleamFloat, GleamInt, GleamList, GleamOption,
  GleamString, GleamTimeOfDay, GleamTimestamp, Query,
}
import parrot/internal/sqlc
import parrot/internal/string_extra

pub fn module(context: sqlc.SQLC) -> Result(model.Module, ParrotError) {
  let enums = used_enums(context)
  use _ <- result.try(check_enums(enums, context.queries))
  use queries <- result.try(list.try_map(context.queries, query(_, context)))

  let unknown_types =
    list.flat_map(context.queries, fn(query) {
      list.filter_map(query.columns, fn(col) {
        case contains(column_type(col, context), GleamDynamic) {
          True -> Ok(col.type_ref.name)
          False -> Error(Nil)
        }
      })
    })

  let enums =
    list.filter_map(enums, fn(enum) {
      case enum.vals {
        [first, ..rest] -> Ok(model.Enum(name: enum.name, first:, rest:))
        [] -> Error(Nil)
      }
    })

  Ok(model.Module(enums:, queries:, unknown_types:))
}

fn query(query: sqlc.Query, context: sqlc.SQLC) -> Result(Query, ParrotError) {
  use <- bool.guard(
    when: list.any(query.columns, fn(col) { option.is_some(col.embed_table) }),
    return: Error(error.UnsupportedEmbedError(query.name)),
  )

  use params <- result.try(
    list.try_map(query.params, fn(param) {
      case escape_keyword(param.column.name) {
        "" -> Error(error.UnnamedParameterError(query.name, param.number))
        name ->
          Ok(model.Param(
            name:,
            type_: column_type(param.column, context),
            slice: param.column.is_sqlc_slice,
          ))
      }
    }),
  )

  use returns_rows <- result.try(case query.cmd {
    sqlc.Exec | sqlc.ExecResult -> Ok(False)
    sqlc.Many | sqlc.One -> Ok(True)
    sqlc.ExecRows
    | sqlc.ExecLastId
    | sqlc.BatchExec
    | sqlc.BatchMany
    | sqlc.BatchOne
    | sqlc.CopyFrom ->
      Error(error.UnsupportedQueryCommandError(
        query.name,
        sqlc.query_cmd_to_string(query.cmd),
      ))
  })

  let columns =
    list.index_map(query.columns, fn(col, index) {
      Field(
        name: field_name(index, query, col),
        type_: column_type(col, context),
      )
    })

  Ok(Query(
    name: query.name,
    sql: split_slices(query),
    returns_rows:,
    params:,
    columns:,
  ))
}

/// sqlc marks slices in the sql as `/*SLICE:name*/?`.
fn split_slices(query: sqlc.Query) -> List(model.SqlPart) {
  list.fold(query.params, [model.Text(query.text)], fn(parts, param) {
    use <- bool.guard(!param.column.is_sqlc_slice, parts)
    let placeholder = "/*SLICE:" <> param.column.name <> "*/?"
    let slice = model.Slice(escape_keyword(param.column.name))
    list.flat_map(parts, fn(part) {
      case part {
        model.Slice(_) -> [part]
        model.Text(text) ->
          string.split(text, placeholder)
          |> list.map(model.Text)
          |> list.intersperse(slice)
      }
    })
  })
}

/// Columns with the same name are prefixed with their table. Unnamed
/// columns are called `col_<index>`.
fn field_name(index: Int, query: sqlc.Query, col: sqlc.TableColumn) -> String {
  let occurrences = list.count(query.columns, fn(c) { c.name == col.name })
  let name = case occurrences > 1, col.table {
    True, option.Some(table) -> table.name <> "_" <> col.name
    _, _ -> col.name
  }
  case string_extra.snake_case(name) {
    "" -> "col_" <> int.to_string(index)
    name -> escape_keyword(name)
  }
}

fn column_type(col: sqlc.TableColumn, context: sqlc.SQLC) -> GleamType {
  use <- bool.lazy_guard(when: !col.not_null, return: fn() {
    GleamOption(column_type(sqlc.TableColumn(..col, not_null: True), context))
  })
  use <- bool.lazy_guard(when: col.is_array, return: fn() {
    GleamList(column_type(sqlc.TableColumn(..col, is_array: False), context))
  })
  use <- bool.lazy_guard(when: col.is_sqlc_slice, return: fn() {
    GleamList(column_type(
      sqlc.TableColumn(..col, is_sqlc_slice: False),
      context,
    ))
  })
  use <- result.lazy_unwrap(
    find_enum(col, context) |> result.map(fn(enum) { GleamEnum(enum.name) }),
  )

  let sql_type = string.lowercase(sql_type_name(col))
  use <- bool.guard(sql_type == "tinyint" && col.length == 1, GleamBool)

  case sql_type {
    // `interval` has to come before `int` and `timetz` before `time`.
    // `timetz` includes an offset, which `TimeOfDay` can not represent.
    "interval" | "timetz" | "time with time zone" -> GleamDynamic
    "int" <> _
    | "tinyint"
    | "smallint"
    | "mediumint"
    | "bigint"
    | "serial" <> _
    | "smallserial"
    | "bigserial"
    | "year" -> GleamInt
    "float" <> _
    | "dec" <> _
    | "fixed"
    | "real"
    | "numeric"
    | "double"
    | "money" <> _ -> GleamFloat
    "char" <> _
    | "bpchar"
    | "varchar" <> _
    | "text" <> _
    | "mediumtext" <> _
    | "longtext" <> _
    | "citext" <> _
    | "json" <> _ -> GleamString
    "uuid"
    | "bit"
    | "blob"
    | "tinyblob"
    | "smallblob"
    | "mediumblob"
    | "longblob"
    | "binary"
    | "varbinary"
    | "byte" <> _ -> GleamBitArray
    "time" | "time without time zone" -> GleamTimeOfDay
    "datetime" <> _ | "time" <> _ -> GleamTimestamp
    "date" <> _ -> GleamDate
    "bool" <> _ -> GleamBool
    _ -> GleamDynamic
  }
}

/// Whether `type_` is or wraps a type like `search`. Enums match any enum.
///
fn contains(type_: GleamType, search: GleamType) -> Bool {
  case type_, search {
    GleamOption(inner), _ | GleamList(inner), _ -> contains(inner, search)
    GleamEnum(_), GleamEnum(_) -> True
    _, _ -> type_ == search
  }
}

fn sql_type_name(col: sqlc.TableColumn) -> String {
  case col.type_ref.name {
    "pg_catalog." <> name | "public." <> name -> name
    name -> name
  }
}

/// Finds the enum a column's type refers to. Errors if the type is not a
/// user defined enum, which includes types from a schema that is not part
/// of the catalog sqlc built up (f.e. one created by an extension).
///
fn find_enum(
  col: sqlc.TableColumn,
  context: sqlc.SQLC,
) -> Result(sqlc.Enum, Nil) {
  let schema_name = case col.type_ref.schema {
    "" | "pg_catalog" -> context.catalog.default_schema
    schema_name -> schema_name
  }
  let name = sql_type_name(col)

  use schema <- result.try(
    list.find(context.catalog.schemas, fn(s) { s.name == schema_name }),
  )
  list.find(schema.enums, fn(e) { e.name == name })
}

/// The enums of all columns and parameters, in order of use.
fn used_enums(context: sqlc.SQLC) -> List(sqlc.Enum) {
  list.flat_map(context.queries, fn(query) {
    query.columns
    |> list.append(list.map(query.params, fn(param) { param.column }))
    |> list.filter_map(fn(col) {
      case contains(column_type(col, context), GleamEnum("")) {
        True -> find_enum(col, context)
        False -> Error(Nil)
      }
    })
  })
  |> list.unique
}

/// Enums become gleam types and their values constructors, so their pascal
/// case names have to be unique.
///
fn check_enums(
  enums: List(sqlc.Enum),
  queries: List(sqlc.Query),
) -> Result(Nil, ParrotError) {
  let enums =
    enums
    |> list.map(fn(enum) { #(string_extra.pascal_case(enum.name), enum.vals) })
    |> list.unique

  let query_clash =
    list.find_map(enums, fn(enum) {
      let #(enum_name, _) = enum
      use query <- result.map(
        list.find(queries, fn(q) {
          string_extra.pascal_case(q.name) == enum_name
        }),
      )
      error.DuplicateDefinitionError(enum_name, query.name)
    })

  let empty_enum =
    list.find_map(enums, fn(enum) {
      case enum {
        #(name, []) -> Ok(error.EmptyEnumError(name))
        _ -> Error(Nil)
      }
    })

  let duplicate_value =
    enums
    |> list.flat_map(fn(enum) {
      let #(enum_name, values) = enum
      list.map(values, fn(value) {
        #(string_extra.pascal_case(value), enum_name)
      })
    })
    |> find_duplicate_value
    |> result.map(fn(duplicate) {
      let #(value, first, second) = duplicate
      error.DuplicateEnumValueError(value, first, second)
    })

  case query_clash, empty_enum, duplicate_value {
    Ok(e), _, _ | _, Ok(e), _ | _, _, Ok(e) -> Error(e)
    _, _, _ -> Ok(Nil)
  }
}

/// Finds the first value that occurs twice, together with the enums of
/// both occurrences. Those can be the same enum, f.e. when an enum has
/// both `open` and `OPEN` as values.
///
fn find_duplicate_value(
  values: List(#(String, String)),
) -> Result(#(String, String, String), Nil) {
  case values {
    [] -> Error(Nil)
    [#(value, enum), ..rest] ->
      case list.find(rest, fn(other) { other.0 == value }) {
        Ok(#(_, other_enum)) -> Ok(#(value, enum, other_enum))
        Error(_) -> find_duplicate_value(rest)
      }
  }
}

fn escape_keyword(name: String) -> String {
  case name {
    "as"
    | "assert"
    | "auto"
    | "case"
    | "const"
    | "delegate"
    | "derive"
    | "echo"
    | "else"
    | "fn"
    | "if"
    | "implement"
    | "import"
    | "let"
    | "macro"
    | "opaque"
    | "panic"
    | "pub"
    | "test"
    | "todo"
    | "type"
    | "use" -> name <> "_"
    _ -> name
  }
}
