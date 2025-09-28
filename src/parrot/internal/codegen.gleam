import given
import gleam/bool
import gleam/dynamic/decode as d
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import parrot/internal/config.{
  type Config, get_json_file, get_module_directory, get_module_path,
}
import parrot/internal/lib
import parrot/internal/sqlc.{type SQLC}
import parrot/internal/string_case
import simplifile

pub type Codegen {
  Codegen(unknown_types: List(String))
}

pub fn codegen_from_config(config: Config) -> Result(Codegen, Nil) {
  use json_string <- lib.try_nil(get_json_file(config))

  use dyn_json <- lib.try_nil(json.parse(from: json_string, using: d.dynamic))

  let assert Ok(context) = sqlc.decode_sqlc(dyn_json)

  // we check for any dynamically mapped types to alert the user that
  // they might have to contribute to this library to cover this case
  let unknowns =
    list.flat_map(context.queries, fn(query) {
      list.map(query.columns, fn(col) {
        case sqlc_col_to_gleam(col, context) {
          GleamDynamic -> {
            option.Some(col.type_ref.name)
          }
          _ -> option.None
        }
      })
    })
    |> list.filter(option.is_some)
    |> list.map(option.unwrap(_, ""))

  let module_contents = gen_gleam_module(context)

  let _ =
    get_module_directory(config)
    |> simplifile.create_directory_all()
  let _ =
    simplifile.write(to: get_module_path(config), contents: module_contents)

  Ok(Codegen(unknowns))
}

fn gen_query(query: sqlc.Query, context: SQLC) {
  let type_str = case list.length(query.columns) {
    0 -> ""
    _ -> gen_query_type(query, context) <> "\n\n"
  }

  let func = gen_query_function(query, context)
  let deco = gen_query_decoder(query, context)
  type_str <> func <> deco
}

pub type GleamType {
  GleamString
  GleamInt
  GleamFloat
  GleamBool
  GleamTimestamp
  GleamDate
  GleamBitArray
  GleamList(GleamType)
  GleamEnum(String)
  GleamOption(GleamType)
  GleamDynamic
}

pub fn gleam_type_to_string(gleamtype: GleamType) -> String {
  case gleamtype {
    GleamBool -> "Bool"
    GleamFloat -> "Float"
    GleamInt -> "Int"
    GleamString -> "String"
    GleamTimestamp -> "Timestamp"
    GleamDate -> "Date"
    GleamBitArray -> "BitArray"
    GleamList(sub) -> "List(" <> gleam_type_to_string(sub) <> ")"
    GleamOption(sub) -> "Option(" <> gleam_type_to_string(sub) <> ")"
    GleamEnum(name) -> string_case.pascal_case(name)
    GleamDynamic -> "decode.Dynamic"
  }
}

fn normalise_col_type(col: sqlc.TableColumn) {
  let type_ = col.type_ref.name
  case type_ {
    "pg_catalog." <> x -> x
    "public." <> x -> x
    x -> x
  }
}

fn find_col_schema(col: sqlc.TableColumn, context: SQLC) {
  let schema_name = col.type_ref.schema

  let schema_name = case schema_name {
    "" | "pg_catalog" -> context.catalog.default_schema
    _ -> schema_name
  }

  let assert Ok(schema) =
    list.find(context.catalog.schemas, fn(s) { s.name == schema_name })

  schema
}

pub fn sqlc_col_to_gleam(col: sqlc.TableColumn, context: SQLC) -> GleamType {
  use <- given.not(col.not_null, return: fn() {
    let col = sqlc.TableColumn(..col, not_null: True)
    let type_ = sqlc_col_to_gleam(col, context)
    GleamOption(type_)
  })

  use <- given.that(col.is_array, return: fn() {
    let col = sqlc.TableColumn(..col, is_array: False)
    let type_ = sqlc_col_to_gleam(col, context)
    GleamList(type_)
  })

  let sqltype = normalise_col_type(col)
  let schema = find_col_schema(col, context)

  let enum =
    schema.enums
    |> list.find(fn(e) { e.name == sqltype })

  use <- given.that(result.is_ok(enum), return: fn() {
    let assert Ok(enum) = enum
    GleamEnum(enum.name)
  })
  let sqltype = string.lowercase(sqltype)

  let tiny_bool = sqltype == "tinyint" && col.length == 1
  use <- bool.guard(tiny_bool, GleamBool)

  case sqltype {
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
    | "varchar" <> _
    | "text" <> _
    | "mediumtext" <> _
    | "longtext" <> _
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
    "datetime" <> _ | "time" <> _ -> GleamTimestamp
    "date" <> _ -> GleamDate
    "bool" <> _ -> GleamBool
    _ -> GleamDynamic
  }
}

pub fn gen_column_name(
  index: Int,
  query: sqlc.Query,
  col: sqlc.TableColumn,
) -> String {
  let occ =
    query.columns
    |> list.count(fn(col2) { col.name == col2.name })
  let result = case occ {
    0 -> panic as { "could not find column name: " <> col.name }
    1 -> col.name
    _ -> {
      case col.table {
        option.None -> col.name
        option.Some(t) -> t.name <> "_" <> col.name
      }
    }
  }
  case string_case.snake_case(result) {
    "" -> "col_" <> int.to_string(index)
    x -> x
  }
}

pub fn gen_query_type(query: sqlc.Query, context: SQLC) {
  let name = string_case.pascal_case(query.name)

  let args =
    query.columns
    |> list.index_map(fn(col, index) {
      let gleam_type = sqlc_col_to_gleam(col, context)
      let col_type = gleam_type_to_string(gleam_type)
      let col_name = gen_column_name(index, query, col)
      col_name <> ": " <> col_type
    })
    |> list.map(fn(str) { "    " <> str })
    |> string.join(",\n")

  ["pub type " <> name <> " {", "  " <> name <> "(", args, "  )", "}"]
  |> string.join("\n")
}

fn gleam_type_to_param(gtype: GleamType) -> String {
  case gtype {
    GleamInt -> "dev.ParamInt"
    GleamString -> "dev.ParamString"
    GleamFloat -> "dev.ParamFloat"
    GleamBool -> "dev.ParamBool"
    GleamTimestamp -> "dev.ParamTimestamp"
    GleamDate -> "dev.ParamDate"
    GleamBitArray -> "dev.ParamBitArray"
    GleamDynamic -> "dev.ParamDynamic"
    GleamEnum(_) -> "dev.ParamString"
    GleamOption(sub) -> "dev.ParamNullable(" <> gleam_type_to_param(sub) <> ")"
    GleamList(sub) -> "dev.ParamList(" <> gleam_type_to_param(sub) <> ")"
  }
}

fn gleam_type_to_return_type(variable: String, gt: GleamType, context: SQLC) {
  let value = case gt {
    GleamEnum(name) -> {
      let name = string_case.snake_case(name)
      name <> "_to_string(" <> variable <> ")"
    }
    _ -> variable
  }
  case gt {
    GleamList(sub_type) -> {
      let sub_param = gleam_type_to_param(sub_type)
      "dev.ParamList(list.map(" <> value <> ", " <> sub_param <> "))"
    }
    GleamOption(sub_type) -> {
      "dev.ParamNullable(option.map("
      <> value
      <> ", fn (v) { "
      <> gleam_type_to_return_type("v", sub_type, context)
      <> " }))"
    }
    _ -> {
      let param = gleam_type_to_param(gt)
      param <> "(" <> value <> ")"
    }
  }
}

pub fn gen_query_function(query: sqlc.Query, context: SQLC) {
  let fn_name = string_case.snake_case(query.name)

  let def_fn_args =
    query.params
    |> list.map(fn(p) {
      let gleam_type = sqlc_col_to_gleam(p.column, context)
      let name = p.column.name

      case name {
        "" ->
          panic as {
              "Parameter name for "
              <> fn_name
              <> " is empty! Please use a named parameter instead (f.e. \"sqlc.arg(name)\" or \"@arg\")"
            }
        _ -> Nil
      }
      name <> " " <> name <> ": " <> gleam_type_to_string(gleam_type)
    })
    |> string.join(", ")

  let def_return_params = case query.params {
    [] -> "[]"
    args ->
      "["
      <> args
      |> list.map(fn(arg) {
        let arg_type = sqlc_col_to_gleam(arg.column, context)
        gleam_type_to_return_type(arg.column.name, arg_type, context)
      })
      |> string.join(", ")
      <> "]"
  }

  let def_fn = "pub fn " <> fn_name <> "(" <> def_fn_args <> ")"
  let def_sql = "let sql = \"" <> query.text <> "\""
  let def_exp = case query.cmd {
    sqlc.Exec | sqlc.ExecResult -> ""
    sqlc.Many | sqlc.One -> fn_name <> "_decoder()"
    sqlc.ExecRows
    | sqlc.ExecLastId
    | sqlc.BatchExec
    | sqlc.BatchMany
    | sqlc.BatchOne
    | sqlc.CopyFrom ->
      panic as {
          "parrot does not support this query annotation: "
          <> sqlc.query_cmd_to_string(query.cmd)
        }
  }
  let def_return = "#(sql, " <> def_return_params <> ", " <> def_exp <> ")"

  [def_fn <> "{", "  " <> def_sql, "  " <> def_return, "}"]
  |> string.join("\n")
}

fn gleam_type_to_decoder(gtype: GleamType) -> String {
  case gtype {
    GleamInt -> "decode.int"
    GleamString -> "decode.string"
    GleamBool -> "dev.bool_decoder()"
    GleamFloat -> "decode.float"
    GleamTimestamp -> "dev.datetime_decoder()"
    GleamDate -> "dev.calendar_date_decoder()"
    GleamBitArray -> "decode.bit_array"
    GleamOption(x) -> "decode.optional(" <> gleam_type_to_decoder(x) <> ")"
    GleamList(x) -> "decode.list(of: " <> gleam_type_to_decoder(x) <> ")"
    GleamEnum(name) -> {
      let name = string_case.snake_case(name)
      name <> "_decoder()"
    }
    GleamDynamic -> "decode.dynamic"
  }
}

pub fn gen_query_decoder(query: sqlc.Query, context: SQLC) {
  case list.length(query.columns) {
    0 -> ""
    _ -> {
      let type_name = string_case.pascal_case(query.name)
      let fn_name = string_case.snake_case(query.name) <> "_decoder"

      let decoder_fields =
        query.columns
        |> list.index_map(fn(col, index) {
          let col_type = sqlc_col_to_gleam(col, context)
          let decoder_type = gleam_type_to_decoder(col_type)

          let col_name = gen_column_name(index, query, col)

          "  use "
          <> col_name
          <> " <- decode.field("
          <> int.to_string(index)
          <> ", "
          <> decoder_type
          <> ")"
        })
        |> string.join("\n")

      let constructor_args =
        query.columns
        |> list.index_map(fn(col, index) {
          gen_column_name(index, query, col) <> ": "
        })
        |> string.join(", ")

      let success_line =
        "  decode.success(" <> type_name <> "(" <> constructor_args <> "))"

      "\n\npub fn "
      <> fn_name
      <> "() -> decode.Decoder("
      <> type_name
      <> ") {\n"
      <> decoder_fields
      <> "\n"
      <> success_line
      <> "\n}"
    }
  }
}

fn uses_gleam_type(case_fn: fn(sqlc.TableColumn) -> Bool, context: SQLC) -> Bool {
  list.any(context.queries, fn(query) {
    let col_ts = list.any(query.columns, fn(col) { case_fn(col) })
    let param_ts = list.any(query.params, fn(param) { case_fn(param.column) })
    bool.or(col_ts, param_ts)
  })
}

pub fn gen_gleam_module(context: SQLC) {
  let queries =
    context.queries
    |> list.map(gen_query(_, context))
    |> string.join("\n\n")

  // check if Timestamps used
  let uses_timestamp =
    fn(col: sqlc.TableColumn) {
      case sqlc_col_to_gleam(col, context) {
        GleamOption(GleamTimestamp) | GleamTimestamp -> True
        _ -> False
      }
    }
    |> uses_gleam_type(context)

  // check if Dates are used
  let uses_date =
    fn(col: sqlc.TableColumn) {
      case sqlc_col_to_gleam(col, context) {
        GleamOption(GleamDate) | GleamDate -> True
        _ -> False
      }
    }
    |> uses_gleam_type(context)

  // checks if Lists are used
  let uses_list =
    fn(col: sqlc.TableColumn) {
      case sqlc_col_to_gleam(col, context) {
        GleamOption(GleamList(_)) | GleamList(_) -> True
        _ -> False
      }
    }
    |> uses_gleam_type(context)

  let timestamp_import = case uses_timestamp {
    False -> ""
    True -> "import gleam/time/timestamp.{type Timestamp}\n"
  }

  let date_import = case uses_date {
    False -> ""
    True -> "import gleam/time/calendar.{type Date}\n"
  }

  let list_import = case uses_list {
    False -> ""
    True -> "import gleam/list\n"
  }

  let imports =
    "import gleam/dynamic/decode"
    <> "\n"
    <> "import gleam/option.{type Option}"
    <> "\n"
    <> date_import
    <> timestamp_import
    <> list_import
    <> "import parrot/dev"

  let enums =
    list.flat_map(context.queries, fn(query) {
      let columns =
        list.filter_map(query.columns, fn(col) {
          case sqlc_col_to_gleam(col, context) {
            GleamOption(GleamEnum(_)) | GleamEnum(_) -> {
              let type_ = normalise_col_type(col)
              let schema = find_col_schema(col, context)

              let assert Ok(enum) =
                schema.enums
                |> list.find(fn(e) { e.name == type_ })

              Ok(enum)
            }
            _ -> Error(Nil)
          }
        })
      let params =
        list.filter_map(query.params, fn(param) {
          case sqlc_col_to_gleam(param.column, context) {
            GleamOption(GleamEnum(_)) | GleamEnum(_) -> {
              let type_ = normalise_col_type(param.column)
              let schema = find_col_schema(param.column, context)

              let assert Ok(enum) =
                schema.enums
                |> list.find(fn(e) { e.name == type_ })

              Ok(enum)
            }
            _ -> Error(Nil)
          }
        })

      list.append(columns, params)
    })
    |> list.unique()
    |> list.map(fn(enum) {
      let record_name = string_case.pascal_case(enum.name)
      let fn_name = string_case.snake_case(enum.name)

      let values =
        list.map(enum.vals, fn(val) { "  " <> string_case.pascal_case(val) })

      let to_str_vals =
        list.map(enum.vals, fn(val) {
          let type_ = string_case.pascal_case(val)
          "    " <> type_ <> " -> " <> "\"" <> val <> "\""
        })

      let decode_str_vals =
        list.map(enum.vals, fn(val) {
          let type_ = string_case.pascal_case(val)
          "    \"" <> val <> "\" -> " <> "decode.success(" <> type_ <> ")"
        })

      let assert Ok(first_value) = list.first(enum.vals)
      let zero_value = string_case.pascal_case(first_value)

      "pub type "
      <> record_name
      <> " {\n"
      <> string.join(values, "\n")
      <> "\n}\n\n"
      //
      <> "pub fn "
      <> fn_name
      <> "_decoder() {\n"
      <> "  use variant <- decode.then(decode.string)\n"
      <> "  case variant {\n"
      <> string.join(decode_str_vals, "\n")
      <> "\n    _ -> decode.failure("
      <> zero_value
      <> ", \""
      <> record_name
      <> "\")\n"
      <> "  }\n"
      <> "}\n\n"
      //
      <> "pub fn "
      <> fn_name
      <> "_to_string(val: "
      <> record_name
      <> ") {\n"
      <> "  case val {\n"
      <> string.join(to_str_vals, "\n")
      <> "\n  }\n"
      <> "}"
    })
    |> string.join("\n\n")

  comment_dont_edit()
  <> "\n\n"
  <> imports
  <> "\n\n"
  <> enums
  <> "\n\n"
  <> queries
}

pub fn comment_dont_edit() {
  "
//// Code generated by parrot. DO NOT EDIT.
////
  "
  |> string.trim()
}
