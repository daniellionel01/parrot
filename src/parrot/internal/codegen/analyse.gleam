//// Turns the output of sqlc into a `model.Module`. Every name is decided and
//// every check that can fail happens here, printing the module can not fail.

import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/set.{type Set}
import gleam/string
import parrot/internal/codegen/model.{
  type EnumNames, type GleamType, EnumNames, Field, GleamBitArray, GleamBool,
  GleamDate, GleamDynamic, GleamEnum, GleamFloat, GleamInet, GleamInt,
  GleamInterval, GleamList, GleamMacaddr, GleamOption, GleamString,
  GleamTimeOfDay, GleamTimestamp, Scalar,
}
import parrot/internal/codegen/runtime
import parrot/internal/error.{type ParrotError}
import parrot/internal/sqlc
import parrot/internal/string_extra

pub fn module(output: sqlc.Output) -> Result(model.Module, ParrotError) {
  use queries <- result.try(
    list.try_map(output.queries, query(_, output.catalog)),
  )

  let field_types =
    list.flat_map(queries, fn(query) {
      case query.returns {
        model.Rows(fields:, ..) -> list.map(fields, fn(field) { field.type_ })
        model.NoRows -> []
      }
    })
  let param_types =
    list.flat_map(queries, fn(query) { list.map(query.params, param_type) })

  // in order of use
  let enums =
    list.append(field_types, param_types)
    |> list.flat_map(enums_in)
    |> list.unique
  use _ <- result.try(check_names(enums, list.zip(output.queries, queries)))

  let unknown_types = field_types |> list.flat_map(unknown_types) |> list.unique
  Ok(model.Module(enums:, queries:, unknown_types:))
}

fn param_type(param: model.Param) -> GleamType {
  case param {
    model.ValueParam(type_:, ..) -> type_
    model.SliceParam(item:, ..) -> item
  }
}

fn query(
  query: sqlc.Query,
  catalog: sqlc.Catalog,
) -> Result(model.Query, ParrotError) {
  use <- bool.guard(
    when: list.any(query.columns, fn(column) { column.is_embed }),
    return: Error(error.UnsupportedEmbed(query.name)),
  )

  use labels <- result.try(
    list.try_map(query.params, fn(param) {
      case escape_keyword(param.column.name) {
        "" -> Error(error.UnnamedParameter(query.name, param.number))
        label -> Ok(label)
      }
    }),
  )

  use command <- result.try(
    list.key_find(commands, query.annotation)
    |> result.replace_error(error.UnsupportedAnnotation(
      query.name,
      query.annotation,
      list.map(commands, fn(command) { command.0 }),
    )),
  )

  let function = string_extra.snake_case(query.name)
  use returns <- result.try(case command {
    WithoutRows -> Ok(model.NoRows)
    WithRows -> {
      use fields <- result.map(fields(query, catalog))
      model.Rows(
        type_: string_extra.pascal_case(query.name),
        decoder: function <> "_decoder",
        fields:,
      )
    }
  })
  use params <- result.try(params(
    query.params,
    unique_labels(labels),
    returns:,
    catalog:,
  ))

  let params_by_number = list.zip(query.params, params)
  let #(sql, values) =
    bind_in_order(split_slices(query.text, params_by_number), params_by_number)

  Ok(model.Query(
    function: escape_keyword(function),
    sql:,
    params:,
    values:,
    returns:,
  ))
}

/// The variables of the query function do not shadow the `sql` it builds,
/// nor the functions it calls.
///
fn params(
  params: List(sqlc.Param),
  labels: List(String),
  returns returns: model.Returns,
  catalog catalog: sqlc.Catalog,
) -> Result(List(model.Param), ParrotError) {
  use params <- result.map(
    list.zip(params, labels)
    |> list.try_map(fn(param) {
      let #(param, label) = param
      case param.column.is_sqlc_slice {
        True -> {
          let item = sqlc.Column(..param.column, not_null: True)
          use type_ <- result.map(column_type(item, catalog))
          #(label, type_, True)
        }
        False -> {
          use type_ <- result.map(column_type(param.column, catalog))
          #(label, type_, False)
        }
      }
    }),
  )

  let decoder = case returns {
    model.Rows(decoder:, ..) -> [decoder]
    model.NoRows -> []
  }
  let to_strings =
    list.flat_map(params, fn(param) {
      list.map(enums_in(param.1), fn(enum) { enum.names.to_string })
    })
  let reserved = set.from_list(["sql", ..list.append(decoder, to_strings)])

  params
  |> list.map_fold(set.union(reserved, set.from_list(labels)), fn(taken, param) {
    let #(label, type_, is_slice) = param
    let variable = case set.contains(reserved, label) {
      True -> suffixed(label, 2, taken)
      False -> label
    }
    let taken = set.insert(taken, variable)
    case is_slice {
      False -> #(taken, model.ValueParam(label:, variable:, type_:))
      True -> {
        let placeholders = unused(variable <> "_slice", taken)
        #(
          set.insert(taken, placeholders),
          model.SliceParam(label:, variable:, placeholders:, item: type_),
        )
      }
    }
  })
  |> pair.second
}

/// The variables of the row decoder do not shadow the decoders it calls.
///
fn fields(
  query: sqlc.Query,
  catalog: sqlc.Catalog,
) -> Result(List(model.Field), ParrotError) {
  let labels =
    list.index_map(query.columns, fn(column, index) {
      field_name(index, query, column)
    })
    |> unique_labels
  use types <- result.map(list.try_map(query.columns, column_type(_, catalog)))

  let enum_decoders =
    list.flat_map(types, fn(type_) {
      list.map(enums_in(type_), fn(enum) { enum.names.decoder })
    })
  let reserved = set.from_list(list.append(runtime.values, enum_decoders))

  list.zip(labels, types)
  |> list.map_fold(set.union(reserved, set.from_list(labels)), fn(taken, field) {
    let #(label, type_) = field
    let variable = case set.contains(reserved, label) {
      True -> suffixed(label, 2, taken)
      False -> label
    }
    #(set.insert(taken, variable), Field(label:, variable:, type_:))
  })
  |> pair.second
}

/// The enums used by a type.
fn enums_in(type_: GleamType) -> List(model.Enum) {
  case type_ {
    Scalar(_) -> []
    GleamEnum(enum) -> [enum]
    GleamList(inner) | GleamOption(inner) -> enums_in(inner)
  }
}

/// The sql types parrot does not know used by a type.
fn unknown_types(type_: GleamType) -> List(String) {
  case type_ {
    Scalar(GleamDynamic(sql_type:)) -> [sql_type]
    Scalar(GleamBitArray)
    | Scalar(GleamBool)
    | Scalar(GleamDate)
    | Scalar(GleamFloat)
    | Scalar(GleamInet)
    | Scalar(GleamInt)
    | Scalar(GleamInterval)
    | Scalar(GleamMacaddr)
    | Scalar(GleamString)
    | Scalar(GleamTimeOfDay)
    | Scalar(GleamTimestamp)
    | GleamEnum(_) -> []
    GleamList(inner) | GleamOption(inner) -> unknown_types(inner)
  }
}

/// Labels that occur more than once get a suffix, like sqlc does for go:
/// `id`, `id_2`.
///
fn unique_labels(labels: List(String)) -> List(String) {
  let all = set.from_list(labels)
  list.map_fold(labels, set.new(), fn(used, label) {
    let label = case set.contains(used, label) {
      True -> suffixed(label, 2, set.union(used, all))
      False -> label
    }
    #(set.insert(used, label), label)
  })
  |> pair.second
}

/// `name`, or else `name` with the first suffix that is not taken.
fn unused(name: String, taken: Set(String)) -> String {
  case set.contains(taken, name) {
    True -> suffixed(name, 2, taken)
    False -> name
  }
}

fn suffixed(name: String, suffix: Int, taken: Set(String)) -> String {
  let candidate = name <> "_" <> int.to_string(suffix)
  case set.contains(taken, candidate) {
    True -> suffixed(name, suffix + 1, taken)
    False -> candidate
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
    #(sqlc_param, model.SliceParam(placeholders:, ..)) -> {
      let placeholder = "/*SLICE:" <> sqlc_param.column.name <> "*/?"
      use part <- list.flat_map(parts)
      case part {
        model.Slice(_) -> [part]
        model.Text(text) ->
          string.split(text, placeholder)
          |> list.map(model.Text)
          |> list.intersperse(model.Slice(placeholders))
      }
    }
  }
}

/// The params in the order the sql binds them.
///
/// For sqlite, sqlc writes named params as `?<number>`, which bind the param
/// with that number, and keeps plain `?`s, which bind the params in the
/// order sqlc lists them. A slice is expanded into one `?` per item, but
/// sqlite numbers each `?` one higher than the highest number so far, so a
/// `?<number>` after a slice binds the wrong item. That's why in queries
/// with slices every `?<number>` is replaced with a plain `?` and the
/// params are bound in the order they occur.
///
fn bind_in_order(
  sql: List(model.SqlPart),
  params: List(#(sqlc.Param, model.Param)),
) -> #(List(model.SqlPart), List(model.Param)) {
  let model_params = list.map(params, pair.second)
  let has_slice =
    list.any(model_params, fn(param) {
      case param {
        model.SliceParam(..) -> True
        model.ValueParam(..) -> False
      }
    })
  use <- bool.guard(!has_slice, #(sql, model_params))

  let sql =
    list.map(sql, fn(part) {
      case part {
        model.Text(text) -> #(part, plain_placeholders(text))
        model.Slice(_) -> #(part, #("", []))
      }
    })
  let numbered =
    list.flat_map(sql, fn(part) {
      list.filter_map(part.1.1, fn(placeholder) {
        case placeholder {
          Numbered(number) -> Ok(number)
          Plain -> Error(Nil)
        }
      })
    })
  // sqlc lists params in the order of their plain `?`s.
  let positional =
    list.filter_map(params, fn(param) {
      case param {
        #(_, model.SliceParam(..)) -> Error(Nil)
        #(sqlc_param, model.ValueParam(..) as param) ->
          case list.contains(numbered, sqlc_param.number) {
            True -> Error(Nil)
            False -> Ok(param)
          }
      }
    })

  let bound =
    list.try_fold(sql, #([], [], positional), fn(acc, part) {
      let #(parts, values, positional) = acc
      case part {
        #(model.Text(_), #(text, placeholders)) -> {
          use #(bound, positional) <- result.map(
            bind_placeholders(placeholders, params, positional, []),
          )
          #([model.Text(text), ..parts], list.append(bound, values), positional)
        }
        #(model.Slice(placeholders) as slice, _) -> {
          use param <- result.map(
            list.find(model_params, fn(param) {
              case param {
                model.SliceParam(placeholders: other, ..) ->
                  other == placeholders
                model.ValueParam(..) -> False
              }
            }),
          )
          #([slice, ..parts], [param, ..values], positional)
        }
      }
    })

  case bound {
    Ok(#(parts, values, [])) -> #(list.reverse(parts), list.reverse(values))
    // Not what sqlc generates, so the sql is left as it is.
    Ok(_) | Error(Nil) -> #(list.map(sql, pair.first), model_params)
  }
}

/// Binds `placeholders` in order. Returns the bound params in reverse and
/// the positional params that are left.
///
fn bind_placeholders(
  placeholders: List(Placeholder),
  params: List(#(sqlc.Param, model.Param)),
  positional: List(model.Param),
  bound: List(model.Param),
) -> Result(#(List(model.Param), List(model.Param)), Nil) {
  case placeholders, positional {
    [], _ -> Ok(#(bound, positional))
    [Plain, ..rest], [param, ..positional] ->
      bind_placeholders(rest, params, positional, [param, ..bound])
    [Plain, ..], [] -> Error(Nil)
    [Numbered(number), ..rest], _ -> {
      use #(_, param) <- result.try(
        list.find(params, fn(param) { { param.0 }.number == number }),
      )
      bind_placeholders(rest, params, positional, [param, ..bound])
    }
  }
}

type Placeholder {
  /// `?`
  Plain
  /// `?<number>`
  Numbered(Int)
}

type Scan {
  Code
  /// inside of quotes, until `end`
  Quoted(end: String)
  LineComment
  BlockComment
}

/// Replaces every `?<number>` in `sql` with `?` and returns the
/// placeholders in order. Placeholders inside of quotes and comments are
/// skipped.
///
fn plain_placeholders(sql: String) -> #(String, List(Placeholder)) {
  scan(string.to_graphemes(sql), Code, [], [])
}

fn scan(
  sql: List(String),
  state: Scan,
  out: List(String),
  placeholders: List(Placeholder),
) -> #(String, List(Placeholder)) {
  case state, sql {
    Code, [] | Quoted(_), [] | LineComment, [] | BlockComment, [] -> #(
      string.concat(list.reverse(out)),
      list.reverse(placeholders),
    )

    Code, ["?", ..rest] -> {
      let #(digits, rest) = list.split_while(rest, is_digit)
      let placeholder = case int.parse(string.concat(digits)) {
        Ok(number) -> Numbered(number)
        Error(_) -> Plain
      }
      scan(rest, Code, ["?", ..out], [placeholder, ..placeholders])
    }
    Code, ["-", "-", ..rest] ->
      scan(rest, LineComment, ["--", ..out], placeholders)
    Code, ["/", "*", ..rest] ->
      scan(rest, BlockComment, ["/*", ..out], placeholders)
    Code, ["'" as quote, ..rest]
    | Code, ["\"" as quote, ..rest]
    | Code, ["`" as quote, ..rest]
    -> scan(rest, Quoted(quote), [quote, ..out], placeholders)
    Code, ["[", ..rest] -> scan(rest, Quoted("]"), ["[", ..out], placeholders)

    Quoted(end), [char, ..rest] if char == end ->
      scan(rest, Code, [char, ..out], placeholders)
    LineComment, ["\n" as char, ..rest]
    | LineComment, ["\r\n" as char, ..rest]
    -> scan(rest, Code, [char, ..out], placeholders)
    BlockComment, ["*", "/", ..rest] ->
      scan(rest, Code, ["*/", ..out], placeholders)

    Code, [char, ..rest]
    | Quoted(_), [char, ..rest]
    | LineComment, [char, ..rest]
    | BlockComment, [char, ..rest]
    -> scan(rest, state, [char, ..out], placeholders)
  }
}

fn is_digit(char: String) -> Bool {
  case char {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

/// Columns with the same name are prefixed with their table. Unnamed
/// columns are called `col_<index>`.
fn field_name(index: Int, query: sqlc.Query, column: sqlc.Column) -> String {
  let occurrences =
    list.count(query.columns, fn(other) { other.name == column.name })
  let name = case occurrences > 1, column.table {
    True, option.Some(table) -> table <> "_" <> column.name
    _, _ -> column.name
  }
  case string_extra.snake_case(name) {
    "" -> "col_" <> int.to_string(index)
    name -> escape_keyword(name)
  }
}

fn column_type(
  column: sqlc.Column,
  catalog: sqlc.Catalog,
) -> Result(GleamType, ParrotError) {
  use <- bool.lazy_guard(when: !column.not_null, return: fn() {
    column_type(sqlc.Column(..column, not_null: True), catalog)
    |> result.map(GleamOption)
  })
  use <- bool.lazy_guard(when: column.is_array, return: fn() {
    column_type(sqlc.Column(..column, is_array: False), catalog)
    |> result.map(GleamList)
  })
  case find_enum(column, catalog) {
    Ok(enum) -> result.map(gleam_enum(enum), GleamEnum)
    Error(_) -> Ok(Scalar(scalar(column)))
  }
}

fn gleam_enum(enum: sqlc.Enum) -> Result(model.Enum, ParrotError) {
  let variants =
    list.map(enum.values, fn(value) {
      model.Variant(name: string_extra.pascal_case(value), value:)
    })
  case variants {
    [first, ..rest] ->
      Ok(model.Enum(
        name: enum.name,
        names: enum_names(enum.name),
        first:,
        rest:,
      ))
    [] -> Error(error.EmptyEnum(enum.name))
  }
}

fn scalar(column: sqlc.Column) -> model.Scalar {
  let sql_type = string.lowercase(sql_type_name(column))
  use <- bool.guard(sql_type == "tinyint" && column.length == 1, GleamBool)

  case sql_type {
    "interval" -> GleamInterval
    // `timetz` includes an offset, which `TimeOfDay` can not represent.
    "timetz" | "time with time zone" -> GleamDynamic(column.type_ref.name)
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
    _ -> GleamDynamic(column.type_ref.name)
  }
}

fn sql_type_name(column: sqlc.Column) -> String {
  case column.type_ref.name {
    "pg_catalog." <> name | "public." <> name -> name
    name -> name
  }
}

/// Finds the enum a column's type refers to. Errors if the type is not a
/// user defined enum, which includes types from a schema that is not part
/// of the catalog sqlc built up (f.e. one created by an extension).
///
fn find_enum(
  column: sqlc.Column,
  catalog: sqlc.Catalog,
) -> Result(sqlc.Enum, Nil) {
  let schema_name = case column.type_ref.schema {
    "" | "pg_catalog" -> catalog.default_schema
    schema_name -> schema_name
  }
  let name = sql_type_name(column)

  use schema <- result.try(
    list.find(catalog.schemas, fn(schema) { schema.name == schema_name }),
  )
  list.find(schema.enums, fn(enum) { enum.name == name })
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
  enums: List(model.Enum),
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
      let model.Enum(name: enum_name, names:, first:, rest:) = enum
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
      Ok(first) -> Error(error.DuplicateDefinition(name:, first:, second:))
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
