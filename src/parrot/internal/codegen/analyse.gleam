//// Turns the output of sqlc into a `model.Module`. Every name is decided and
//// every check that can fail happens here, printing the module can not fail.

import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/string
import parrot/error.{type ParrotError}
import parrot/internal/codegen/model.{
  type EnumNames, type GleamType, EnumNames, Field, GleamBitArray, GleamBool,
  GleamDate, GleamDynamic, GleamEnum, GleamFloat, GleamInet, GleamInt,
  GleamInterval, GleamList, GleamMacaddr, GleamOption, GleamString,
  GleamTimeOfDay, GleamTimestamp, Scalar,
}
import parrot/internal/codegen/runtime
import parrot/internal/sqlc
import parrot/internal/string_extra

pub fn module(output: sqlc.Output) -> Result(model.Module, ParrotError) {
  let catalog = output.catalog
  use queries <- result.try(list.try_map(output.queries, query(_, catalog)))
  use enums <- result.try(enums(used_enums(output)))
  use _ <- result.try(check_names(enums, list.zip(output.queries, queries)))

  let unknown_types =
    output.queries
    |> list.flat_map(fn(query) {
      use col <- list.filter_map(query.columns)
      case innermost(column_type(col, catalog)) {
        Scalar(GleamDynamic) -> Ok(col.type_ref.name)
        _ -> Error(Nil)
      }
    })
    |> list.unique

  Ok(model.Module(enums: list.map(enums, pair.second), queries:, unknown_types:))
}

fn query(
  query: sqlc.Query,
  catalog: sqlc.Catalog,
) -> Result(model.Query, ParrotError) {
  use <- bool.guard(
    when: list.any(query.columns, fn(col) { col.is_embed }),
    return: Error(error.UnsupportedEmbedError(query.name)),
  )

  use params <- result.try(
    list.try_map(query.params, param(_, query.name, catalog)),
  )

  use command <- result.try(
    list.key_find(commands, query.cmd)
    |> result.replace_error(error.UnsupportedQueryCommandError(
      query.name,
      query.cmd,
      list.map(commands, fn(command) { command.0 }),
    )),
  )

  let function = string_extra.snake_case(query.name)
  let returns = case command {
    WithoutRows -> model.NoRows
    WithRows ->
      model.Rows(
        type_: string_extra.pascal_case(query.name),
        decoder: function <> "_decoder",
        fields: list.index_map(query.columns, fn(col, index) {
          Field(
            name: field_name(index, query, col),
            type_: column_type(col, catalog),
          )
        }),
      )
  }

  Ok(model.Query(
    function: escape_keyword(function),
    sql: split_slices(query.text, list.zip(query.params, params)),
    params:,
    returns:,
  ))
}

fn param(
  param: sqlc.Param,
  query: String,
  catalog: sqlc.Catalog,
) -> Result(model.Param, ParrotError) {
  case escape_keyword(param.column.name), param.column.is_sqlc_slice {
    "", _ -> Error(error.UnnamedParameterError(query, param.number))
    name, True -> {
      let item = sqlc.Column(..param.column, not_null: True)
      Ok(model.SliceParam(name:, item: column_type(item, catalog)))
    }
    name, False ->
      Ok(model.ValueParam(name:, type_: column_type(param.column, catalog)))
  }
}

type Command {
  WithRows
  WithoutRows
}

/// The query annotations parrot supports.
const commands = [
  #(":one", WithRows),
  #(":many", WithRows),
  #(":exec", WithoutRows),
  #(":execresult", WithoutRows),
]

fn enum_names(name: String) -> EnumNames {
  let function = string_extra.snake_case(name)
  EnumNames(
    type_: string_extra.pascal_case(name),
    to_string: function <> "_to_string",
    decoder: function <> "_decoder",
  )
}

/// sqlc marks slices in the sql as `/*SLICE:name*/?`.
fn split_slices(
  text: String,
  params: List(#(sqlc.Param, model.Param)),
) -> List(model.SqlPart) {
  use parts, param <- list.fold(params, [model.Text(text)])
  case param {
    #(_, model.ValueParam(..)) -> parts
    #(sqlc_param, model.SliceParam(name:, ..)) -> {
      let placeholder = "/*SLICE:" <> sqlc_param.column.name <> "*/?"
      use part <- list.flat_map(parts)
      case part {
        model.Slice(_) -> [part]
        model.Text(text) ->
          string.split(text, placeholder)
          |> list.map(model.Text)
          |> list.intersperse(model.Slice(name))
      }
    }
  }
}

/// Columns with the same name are prefixed with their table. Unnamed
/// columns are called `col_<index>`.
fn field_name(index: Int, query: sqlc.Query, col: sqlc.Column) -> String {
  let occurrences = list.count(query.columns, fn(c) { c.name == col.name })
  let name = case occurrences > 1, col.table {
    True, option.Some(table) -> table <> "_" <> col.name
    _, _ -> col.name
  }
  case string_extra.snake_case(name) {
    "" -> "col_" <> int.to_string(index)
    name -> escape_keyword(name)
  }
}

fn column_type(col: sqlc.Column, catalog: sqlc.Catalog) -> GleamType {
  use <- bool.lazy_guard(when: !col.not_null, return: fn() {
    GleamOption(column_type(sqlc.Column(..col, not_null: True), catalog))
  })
  use <- bool.lazy_guard(when: col.is_array, return: fn() {
    GleamList(column_type(sqlc.Column(..col, is_array: False), catalog))
  })
  case find_enum(col, catalog) {
    Ok(enum) -> GleamEnum(enum_names(enum.name))
    Error(_) -> Scalar(scalar(col))
  }
}

fn scalar(col: sqlc.Column) -> model.Scalar {
  let sql_type = string.lowercase(sql_type_name(col))
  use <- bool.guard(sql_type == "tinyint" && col.length == 1, GleamBool)

  case sql_type {
    "interval" -> GleamInterval
    // `timetz` includes an offset, which `TimeOfDay` can not represent.
    "timetz" | "time with time zone" -> GleamDynamic
    "inet" | "cidr" -> GleamInet
    "macaddr" -> GleamMacaddr
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

fn innermost(type_: GleamType) -> GleamType {
  case type_ {
    GleamOption(inner) | GleamList(inner) -> innermost(inner)
    _ -> type_
  }
}

fn sql_type_name(col: sqlc.Column) -> String {
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
  col: sqlc.Column,
  catalog: sqlc.Catalog,
) -> Result(sqlc.Enum, Nil) {
  let schema_name = case col.type_ref.schema {
    "" | "pg_catalog" -> catalog.default_schema
    schema_name -> schema_name
  }
  let name = sql_type_name(col)

  use schema <- result.try(
    list.find(catalog.schemas, fn(s) { s.name == schema_name }),
  )
  list.find(schema.enums, fn(e) { e.name == name })
}

/// The enums of all columns and parameters, in order of use.
fn used_enums(output: sqlc.Output) -> List(sqlc.Enum) {
  list.flat_map(output.queries, fn(query) {
    query.columns
    |> list.append(list.map(query.params, fn(param) { param.column }))
    |> list.filter_map(fn(col) {
      case innermost(column_type(col, output.catalog)) {
        GleamEnum(_) -> find_enum(col, output.catalog)
        _ -> Error(Nil)
      }
    })
  })
  |> list.unique
}

/// Each enum together with its name in the database.
///
fn enums(
  enums: List(sqlc.Enum),
) -> Result(List(#(String, model.Enum)), ParrotError) {
  use enum <- list.try_map(enums)
  let variants =
    list.map(enum.vals, fn(value) {
      model.Variant(name: string_extra.pascal_case(value), value:)
    })
  case variants {
    [first, ..rest] ->
      Ok(#(enum.name, model.Enum(names: enum_names(enum.name), first:, rest:)))
    [] -> Error(error.EmptyEnumError(enum.name))
  }
}

type Namespace {
  Types
  /// constructors and functions
  Values
}

/// Every type, constructor and function of the generated module has to have
/// a unique name, also the ones of parrot's own code. Otherwise the module
/// does not compile, or one of them silently shadows an imported one.
///
fn check_names(
  enums: List(#(String, model.Enum)),
  queries: List(#(sqlc.Query, model.Query)),
) -> Result(Nil, ParrotError) {
  let runtime =
    list.append(
      list.map(runtime.types, fn(name) {
        #(Types, name, error.RuntimeDefinition)
      }),
      list.map(runtime.values, fn(name) {
        #(Values, name, error.RuntimeDefinition)
      }),
    )

  let enums =
    list.flat_map(enums, fn(enum) {
      let #(enum_name, model.Enum(names:, first:, rest:)) = enum
      let definition = error.EnumDefinition(enum_name)
      let variants =
        list.map([first, ..rest], fn(variant) {
          #(
            Values,
            variant.name,
            error.EnumValueDefinition(enum_name, variant.value),
          )
        })
      [
        #(Types, names.type_, definition),
        #(Values, names.decoder, definition),
        #(Values, names.to_string, definition),
        ..variants
      ]
    })

  let queries =
    list.flat_map(queries, fn(query) {
      let #(sqlc_query, query) = query
      let definition = error.QueryDefinition(sqlc_query.name)
      let function = #(Values, query.function, definition)
      case query.returns {
        model.NoRows -> [function]
        model.Rows(type_:, decoder:, ..) -> [
          function,
          #(Types, type_, definition),
          #(Values, type_, definition),
          #(Values, decoder, definition),
        ]
      }
    })

  [runtime, enums, queries]
  |> list.flatten
  |> list.try_fold(dict.new(), fn(defined, definition) {
    let #(namespace, name, second) = definition
    case dict.get(defined, #(namespace, name)) {
      Ok(first) -> Error(error.DuplicateDefinitionError(name:, first:, second:))
      Error(_) -> Ok(dict.insert(defined, #(namespace, name), second))
    }
  })
  |> result.replace(Nil)
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
