//// The messages of the errors that are not covered by `codegen_test`.

import birdie
import child_process
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import parrot/internal/command
import parrot/internal/error
import simplifile
import tom

pub fn error_messages_test() {
  [
    error.UnknownArgument("--wibble"),
    error.MissingFlagValue("--sqlite"),
    error.CouldNotReadGleamToml("/app/gleam.toml", simplifile.Eacces),
    error.InvalidGleamToml(
      "/app/gleam.toml",
      tom.Unexpected(got: "=", expected: "a key"),
    ),
    error.InvalidGleamToml(
      "/app/gleam.toml",
      tom.KeyAlreadyInUse(["tools", "parrot", "output"]),
    ),
    error.InvalidGleamTomlValue(tom.NotFound(["name"])),
    error.InvalidGleamTomlValue(tom.WrongType(
      ["tools", "parrot", "output"],
      expected: "String",
      got: "Int",
    )),
    error.UnknownEngine("oracle"),
    error.MissingEngine(schema: "priv/schema.sql"),
    error.UnknownConnectionString("DATABASE_URL"),
    error.MissingConnectionString("DATABASE_URL"),
    error.CouldNotReadQueries("/app/src", simplifile.Eacces),
    error.NoQueriesFound("/app/src"),
    error.SqliteDatabaseNotFound("/app/app.db"),
    error.InvalidConnectionString("mysql://user:password@host:port/database"),
    error.CouldNotFetchSchema(
      "pg_dump",
      command.CouldNotStart(child_process.FileNotFound("pg_dump")),
    ),
    error.CouldNotFetchSchema("pg_dump", command.Failed(1, None)),
    error.UnsupportedPlatform(os: "freebsd", cpu: "amd64"),
    error.SqlcDownloadFailed(
      "https://downloads.sqlc.dev/sqlc.tar.gz",
      error.RequestFailed(httpc.FailedToConnect(
        httpc.Posix("nxdomain"),
        httpc.Posix("nxdomain"),
      )),
    ),
    error.SqlcDownloadFailed(
      "https://downloads.sqlc.dev/sqlc.tar.gz",
      error.UnexpectedStatus(404),
    ),
    error.SqlcDownloadFailed(
      "https://downloads.sqlc.dev/sqlc.tar.gz",
      error.BinaryNotInArchive,
    ),
    error.SqlcChecksumMismatch(
      "https://downloads.sqlc.dev/sqlc.tar.gz",
      expected: "abc",
      received: "def",
    ),
    error.CouldNotInstallSqlc("/app/build/.parrot/sqlc", simplifile.Enospc),
    error.SqlcNotInPath,
    error.CouldNotRunSqlc(
      "/usr/bin/sqlc",
      command.Failed(2, Some("unknown command")),
    ),
    error.SqlcFailed(command.Failed(1, Some("queries.sql:1:1: syntax error"))),
    error.SqlcFailed(command.Failed(1, Some(""))),
    error.CouldNotUseWorkDirectory("/app/build/.parrot", simplifile.Eacces),
    error.UnexpectedSqlcOutput(json.UnexpectedEndOfInput),
    error.CouldNotWriteModule("/app/src/app/sql.gleam", simplifile.Eacces),
    error.CouldNotFormatModule(
      "/app/src/app/sql.gleam",
      command.Failed(1, Some("error: Syntax error")),
    ),
  ]
  |> list.map(error.to_string)
  |> string.join("\n\n")
  |> birdie.snap(title: "error messages")
}
