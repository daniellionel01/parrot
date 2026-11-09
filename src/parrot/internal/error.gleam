import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/string
import parrot/internal/command.{type CommandError}
import simplifile
import tom

pub type ParrotError {
  // === CONFIGURATION ========================================================
  UnknownArgument(argument: String)
  MissingFlagValue(flag: String)
  CouldNotReadGleamToml(path: String, reason: simplifile.FileError)
  InvalidGleamToml(path: String, reason: tom.ParseError)
  InvalidGleamTomlValue(reason: tom.GetError)
  UnknownEngine(name: String)
  MissingEngine(schema: String)
  /// Leaves out the connection string, it may contain a password.
  UnknownConnectionString(env_var: String)
  MissingConnectionString(env_var: String)

  // === PROJECT ==============================================================
  CouldNotReadQueries(path: String, reason: simplifile.FileError)
  NoQueriesFound(directory: String)

  // === DATABASE =============================================================
  SqliteDatabaseNotFound(path: String)
  /// Leaves out the connection string, it may contain a password.
  InvalidConnectionString(expected: String)
  CouldNotFetchSchema(executable: String, reason: CommandError)

  // === SQLC =================================================================
  UnsupportedPlatform(os: String, cpu: String)
  SqlcDownloadFailed(url: String, reason: DownloadError)
  SqlcChecksumMismatch(url: String, expected: String, received: String)
  CouldNotInstallSqlc(path: String, reason: simplifile.FileError)
  SqlcNotInPath
  CouldNotRunSqlc(binary: String, reason: CommandError)
  /// sqlc ran but exited with an error, e.g. on an invalid query.
  SqlcFailed(reason: CommandError)
  CouldNotUseWorkDirectory(path: String, reason: simplifile.FileError)
  UnexpectedSqlcOutput(reason: json.DecodeError)

  // === CODE GENERATION ======================================================
  DuplicateDefinition(name: String, first: Definition, second: Definition)
  EmptyEnum(enum: String)
  UnnamedParameter(query: String, position: Int)
  UnsupportedAnnotation(
    query: String,
    annotation: String,
    supported: List(String),
  )
  UnsupportedEmbed(query: String)
  CouldNotWriteModule(path: String, reason: simplifile.FileError)
  CouldNotFormatModule(path: String, reason: CommandError)
}

pub type DownloadError {
  RequestFailed(httpc.HttpError)
  UnexpectedStatus(Int)
  BinaryNotInArchive
}

/// What defines a name in the generated module.
pub type Definition {
  /// Shared runtime code, its imports and gleam's prelude.
  RuntimeDefinition
  /// The enum's type and functions.
  EnumDefinition(enum: String)
  /// A value's constructor.
  EnumValueDefinition(enum: String, value: String)
  /// The query's function, and the row type, constructor and decoder if it
  /// returns rows.
  QueryDefinition(query: String)
}

const issues = "https://github.com/daniellionel01/parrot/issues"

const help = "See `gleam run -m parrot -- --help`."

pub fn to_string(error: ParrotError) -> String {
  case error {
    UnknownArgument(argument:) ->
      "unknown argument `" <> argument <> "`. " <> help
    MissingFlagValue(flag:) -> "`" <> flag <> "` needs a value. " <> help
    CouldNotReadGleamToml(path:, reason:) ->
      "could not read `" <> path <> "`: " <> simplifile.describe_error(reason)
    InvalidGleamToml(path:, reason:) ->
      "`" <> path <> "` is not valid toml: " <> describe_parse_error(reason)
    InvalidGleamTomlValue(reason:) ->
      "invalid gleam.toml: " <> describe_get_error(reason)
    UnknownEngine(name:) ->
      "unknown engine: " <> name <> ". Expected postgresql, mysql or sqlite."
    MissingEngine(schema:) ->
      "could not detect the database engine of the schema `"
      <> schema
      <> "`. Set `engine` in `[tools.parrot]` or pass `--engine`."
    UnknownConnectionString(env_var:) ->
      "could not detect the database engine from the connection string in `"
      <> env_var
      <> "`. It has to start with `postgres`, `mysql`, `sqlite:` or `file:`. "
      <> "Otherwise set `engine` in `[tools.parrot]` or pass `--engine`."
    MissingConnectionString(env_var:) ->
      "the environment variable `"
      <> env_var
      <> "` is not set. Set it to the connection string of your database, "
      <> "or use `--sqlite <PATH>` or `--schema <PATH>`."

    CouldNotReadQueries(path:, reason:) ->
      "could not read `"
      <> path
      <> "` while looking for queries: "
      <> simplifile.describe_error(reason)
    NoQueriesFound(directory:) ->
      "no queries were found in `"
      <> directory
      <> "`. Parrot looks for `*.sql` files inside of `sql` directories, "
      <> "f.e. `src/app/sql/users.sql`."

    SqliteDatabaseNotFound(path:) ->
      "sqlite database `" <> path <> "` does not exist"
    InvalidConnectionString(expected:) ->
      "could not parse the connection string. Expected the format: " <> expected
    CouldNotFetchSchema(executable:, reason:) ->
      "could not fetch the database schema with `"
      <> executable
      <> "`:\n"
      <> command.describe_error(reason)

    UnsupportedPlatform(os:, cpu:) ->
      "parrot can not download sqlc for "
      <> os
      <> " "
      <> cpu
      <> ". If you have a sqlc binary, set `bin` in `[tools.parrot.sqlc]` "
      <> "or pass `--sqlc` with its path."
    SqlcDownloadFailed(url:, reason:) ->
      "could not download sqlc from "
      <> url
      <> ": "
      <> describe_download_error(reason)
    SqlcChecksumMismatch(url:, expected:, received:) ->
      "the sqlc binary downloaded from "
      <> url
      <> " does not match the expected checksum. "
      <> "This could mean the download was corrupted or tampered with.\n"
      <> "expected: "
      <> expected
      <> "\nreceived: "
      <> received
    CouldNotInstallSqlc(path:, reason:) ->
      "could not save sqlc to `"
      <> path
      <> "`: "
      <> simplifile.describe_error(reason)
    SqlcNotInPath ->
      "`sqlc` is not in the PATH. Install it, or remove `--sqlc system` and "
      <> "`bin = \"system\"` in `[tools.parrot.sqlc]` to let parrot download it."
    CouldNotRunSqlc(binary:, reason:) ->
      "could not run sqlc `"
      <> binary
      <> "`: "
      <> command.describe_error(reason)
    SqlcFailed(reason:) ->
      "could not call `sqlc generate`:\n" <> command.describe_error(reason)
    CouldNotUseWorkDirectory(path:, reason:) ->
      "could not access `"
      <> path
      <> "`, which parrot uses to run sqlc: "
      <> simplifile.describe_error(reason)
    UnexpectedSqlcOutput(reason:) ->
      "could not read the output of sqlc: "
      <> describe_json_error(reason)
      <> "\nThis is most likely a bug in parrot, please open an issue: "
      <> issues

    DuplicateDefinition(name:, first:, second:) ->
      "`"
      <> name
      <> "` would be defined twice in the generated module, by "
      <> describe_definition(first)
      <> " and by "
      <> describe_definition(second)
      <> ". "
      <> case first, second {
        _, QueryDefinition(query:) | QueryDefinition(query:), _ ->
          "Consider renaming the query '" <> query <> "'."
        RuntimeDefinition, _ | _, RuntimeDefinition ->
          "Parrot can not generate this name yet, please open an issue: "
          <> issues
        EnumDefinition(..), _ | EnumValueDefinition(..), _ ->
          "Names in a gleam module must be unique, after parrot converts "
          <> "enum names and values to PascalCase."
      }
    EmptyEnum(enum:) ->
      "enum '"
      <> enum
      <> "' has no variants. "
      <> "Empty enums cannot be represented in Gleam. "
      <> "Please add values to the enum or remove it from your schema."
    UnnamedParameter(query:, position:) ->
      "parameter $"
      <> int.to_string(position)
      <> " of query '"
      <> query
      <> "' has no name, so parrot can not generate a function argument for it. "
      <> "Please use a named parameter instead, f.e. \"sqlc.arg(name)\" or \"@name\"."
    UnsupportedEmbed(query:) ->
      "query '"
      <> query
      <> "' uses `sqlc.embed`, which parrot does not support yet. "
      <> "Select the columns instead."
    UnsupportedAnnotation(query:, annotation:, supported:) ->
      "query '"
      <> query
      <> "' uses the annotation "
      <> annotation
      <> ", which parrot does not support. "
      <> "Supported annotations are "
      <> enumerate(supported)
      <> "."
    CouldNotWriteModule(path:, reason:) ->
      "could not write the generated module `"
      <> path
      <> "`: "
      <> simplifile.describe_error(reason)
    CouldNotFormatModule(path:, reason:) ->
      "could not format the generated module `"
      <> path
      <> "`:\n"
      <> command.describe_error(reason)
  }
}

fn describe_parse_error(error: tom.ParseError) -> String {
  case error {
    tom.Unexpected(got:, expected:) ->
      "expected " <> expected <> " but found " <> got
    tom.KeyAlreadyInUse(key:) ->
      "`" <> string.join(key, ".") <> "` is defined more than once"
  }
}

fn describe_get_error(error: tom.GetError) -> String {
  case error {
    tom.NotFound(key:) -> "`" <> string.join(key, ".") <> "` is missing"
    tom.WrongType(key:, expected:, got:) ->
      "`"
      <> string.join(key, ".")
      <> "` has to be of type "
      <> expected
      <> ", not "
      <> got
  }
}

fn describe_download_error(error: DownloadError) -> String {
  case error {
    RequestFailed(httpc.InvalidUtf8Response) ->
      "the response is not valid UTF-8"
    RequestFailed(httpc.FailedToConnect(ip4:, ..)) ->
      "could not connect, " <> describe_connect_error(ip4)
    RequestFailed(httpc.ResponseTimeout) -> "the request timed out"
    UnexpectedStatus(status) ->
      "the server responded with status " <> int.to_string(status)
    BinaryNotInArchive -> "the download does not contain a sqlc binary"
  }
}

fn describe_connect_error(error: httpc.ConnectError) -> String {
  case error {
    httpc.Posix(code:) -> code
    httpc.TlsAlert(code:, detail:) -> code <> ": " <> detail
  }
}

fn describe_json_error(error: json.DecodeError) -> String {
  case error {
    json.UnexpectedEndOfInput -> "unexpected end of input"
    json.UnexpectedByte(byte) -> "unexpected byte " <> byte
    json.UnexpectedSequence(sequence) -> "unexpected sequence " <> sequence
    json.UnableToDecode(errors) ->
      errors
      |> list.map(fn(error) {
        "expected "
        <> error.expected
        <> " but found "
        <> error.found
        <> " at "
        <> string.join(error.path, ".")
      })
      |> string.join(", ")
  }
}

fn describe_definition(definition: Definition) -> String {
  case definition {
    RuntimeDefinition -> "parrot's own code"
    EnumDefinition(enum:) -> "enum '" <> enum <> "'"
    EnumValueDefinition(enum:, value:) ->
      "value '" <> value <> "' of enum '" <> enum <> "'"
    QueryDefinition(query:) -> "query '" <> query <> "'"
  }
}

/// `a, b and c`
fn enumerate(items: List(String)) -> String {
  case list.reverse(items) {
    [] -> ""
    [last] -> last
    [last, ..rest] -> string.join(list.reverse(rest), ", ") <> " and " <> last
  }
}
