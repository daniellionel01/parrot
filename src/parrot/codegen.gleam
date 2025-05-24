import gleam/bool
import gleam/dynamic/decode as d
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import parrot/config.{
  type Config, get_json_file, get_module_directory, get_module_path,
}
import parrot/internal/colored
import parrot/internal/lib
import parrot/internal/sqlc.{type SQLC}
import parrot/internal/string_case
import simplifile

pub fn codegen_from_config(config: Config) {
  use json_string <- lib.try_nil(get_json_file(config))

  use dyn_json <- lib.try_nil(json.parse(from: json_string, using: d.dynamic))

  let assert Ok(parsed) = sqlc.decode_sqlc(dyn_json)

  // we check for any dynamically mapped types to alert the user that
  // they might have to contribute to this library to cover this case
  list.each(parsed.queries, fn(query) {
    list.each(query.columns, fn(col) {
      case sqlc_type_to_gleam(col.type_ref.name) {
        GleamDynamic -> {
          io.println(colored.yellow(
            "unknown column type: " <> col.type_ref.name,
          ))
        }
        _ -> Nil
      }
    })
  })
  io.println("")

  let module_contents = gen_gleam_module(parsed)

  let _ =
    get_module_directory(config)
    |> simplifile.create_directory_all()
  let _ =
    simplifile.write(to: get_module_path(config), contents: module_contents)

  Ok(Nil)
}

fn gen_query(query: sqlc.Query) {
  let type_str = case list.length(query.columns) {
    0 -> ""
    _ -> gen_query_type(query) <> "\n\n"
  }

  type_str <> gen_query_function(query) <> gen_query_decoder(query)
}

pub type GleamType {
  GleamString
  GleamInt
  GleamFloat
  GleamBool
  GleamTimestamp
  GleamDynamic
}

pub fn gleam_type_to_string(gleamtype: GleamType) -> String {
  case gleamtype {
    GleamBool -> "Bool"
    GleamFloat -> "Float"
    GleamInt -> "Int"
    GleamString -> "String"
    GleamTimestamp -> "Timestamp"
    GleamDynamic -> "decode.Dynamic"
  }
}

pub fn sqlc_type_to_gleam(sqltype: String) -> GleamType {
  let sqltype = case sqltype {
    "pg_catalog." <> x -> x
    x -> x
  }
  case string.lowercase(sqltype) {
    "int" <> _ | "integer" | "bigint" | "bigserial" -> GleamInt
    "float"
    | "decimal"
    | "real"
    | "numeric"
    | "double precision"
    | "smallserial"
    | "serial"
    | "bigserial" -> GleamFloat
    "text" | "varchar" | "uuid" -> GleamString
    "datetime" | "timestamp" -> GleamTimestamp
    _ -> GleamDynamic
  }
}

pub fn gen_column_name(query: sqlc.Query, col: sqlc.TableColumn) -> String {
  let occ =
    query.columns
    |> list.count(fn(col2) { col.name == col2.name })
  let result = case occ {
    0 -> panic as "could not find column name"
    1 -> col.name
    _ -> {
      case col.table {
        option.None -> col.name
        option.Some(t) -> t.name <> "_" <> col.name
      }
    }
  }
  string_case.snake_case(result)
}

pub fn gen_query_type(query: sqlc.Query) {
  let name = string_case.pascal_case(query.name)

  let args =
    query.columns
    |> list.map(fn(col) {
      let gleam_type = sqlc_type_to_gleam(col.type_ref.name)
      let col_type = gleam_type_to_string(gleam_type)
      let col_type = case col.not_null {
        True -> col_type
        False -> "Option(" <> col_type <> ")"
      }
      let col_name = gen_column_name(query, col)
      col_name <> ": " <> col_type
    })
    |> list.map(fn(str) { "    " <> str })
    |> string.join(",\n")

  ["pub type " <> name <> " {", "  " <> name <> "(", args, "  )", "}"]
  |> string.join("\n")
}

pub fn gen_query_function(query: sqlc.Query) {
  let fn_name = string_case.snake_case(query.name)

  let def_fn_args =
    query.params
    |> list.map(fn(p) {
      let gleam_type = sqlc_type_to_gleam(p.column.type_ref.name)
      p.column.name <> ": " <> gleam_type_to_string(gleam_type)
    })
    |> string.join(", ")

  let def_return_params = case query.params {
    [] -> "Nil"
    args ->
      "["
      <> args
      |> list.map(fn(arg) {
        let arg_type = sqlc_type_to_gleam(arg.column.type_ref.name)
        let param = case arg_type {
          GleamInt -> "sql.ParamInt"
          GleamString -> "sql.ParamString"
          GleamFloat -> "sql.ParamFloat"
          GleamBool -> "sql.ParamBool"
          GleamTimestamp -> "sql.ParamTimestamp"
          GleamDynamic -> "sql.ParamDynamic"
        }
        param <> "(" <> arg.column.name <> ")"
      })
      |> string.join(", ")
      <> "]"
  }

  let def_fn = "pub fn " <> fn_name <> "(" <> def_fn_args <> ")"
  let def_sql = "let sql = \"" <> query.text <> "\""
  let def_return = "#(sql, " <> def_return_params <> ")"

  [def_fn <> "{", "  " <> def_sql, "  " <> def_return, "}"]
  |> string.join("\n")
}

pub fn gen_query_decoder(query: sqlc.Query) {
  case list.length(query.columns) {
    0 -> ""
    _ -> {
      let type_name = string_case.pascal_case(query.name)
      let fn_name = string_case.snake_case(query.name) <> "_decoder"

      let decoder_fields =
        query.columns
        |> list.index_map(fn(col, index) {
          let col_type = sqlc_type_to_gleam(col.type_ref.name)
          let decoder_type = case col_type {
            GleamInt -> "decode.int"
            GleamString -> "decode.string"
            GleamBool -> "decode.bool"
            GleamFloat -> "decode.float"
            GleamTimestamp -> "sql.datetime_decoder()"
            GleamDynamic -> "decode.dynamic"
          }

          let decoder = case col.not_null {
            True -> decoder_type
            False -> "decode.optional(" <> decoder_type <> ")"
          }
          let col_name = gen_column_name(query, col)

          "  use "
          <> col_name
          <> " <- decode.field("
          <> int.to_string(index)
          <> ", "
          <> decoder
          <> ")"
        })
        |> string.join("\n")

      let constructor_args =
        query.columns
        |> list.map(fn(col) { gen_column_name(query, col) <> ": " })
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

pub fn gen_gleam_module(schema: SQLC) {
  let queries =
    schema.queries
    |> list.map(gen_query)
    |> string.join("\n\n")

  let uses_timestamp =
    list.any(schema.queries, fn(query) {
      let col_ts =
        list.any(query.columns, fn(col) {
          case sqlc_type_to_gleam(col.type_ref.name) {
            GleamTimestamp -> True
            _ -> False
          }
        })
      let param_ts =
        list.any(query.params, fn(param) {
          case sqlc_type_to_gleam(param.column.type_ref.name) {
            GleamTimestamp -> True
            _ -> False
          }
        })

      bool.or(col_ts, param_ts)
    })

  let timestamp_import = case uses_timestamp {
    False -> ""
    True -> "import gleam/time/timestamp.{type Timestamp}\n"
  }

  let imports =
    "import gleam/option.{type Option}"
    <> "\n"
    <> "import gleam/dynamic/decode"
    <> "\n"
    <> timestamp_import
    <> "import parrot/sql"

  comment_dont_edit() <> "\n\n" <> imports <> "\n\n" <> queries
}

pub fn comment_dont_edit() {
  "
  //// Code generated by parrot. DO NOT EDIT.
  ////
  "
  |> lib.dedent
}
