import argv
import child_process
import envoy
import filepath
import gleam/bool
import gleam/io
import gleam/list
import gleam/result
import parrot/internal/cli
import parrot/internal/codegen
import parrot/internal/config
import parrot/internal/database
import parrot/internal/error
import parrot/internal/project
import parrot/internal/sqlc

pub fn main() -> Nil {
  let result = {
    use command <- result.try(cli.parse(argv.load().arguments))
    case command {
      cli.Help -> Ok(cli.usage)
      cli.Generate(flags) -> {
        let root = project.root()
        use toml <- result.try(project.toml(root))
        case project.parrot_is_dependency(toml) {
          True ->
            io.println_error(cli.yellow(
              "warning: parrot is only needed during development, move it to "
              <> "[dev-dependencies]: gleam remove parrot && gleam add --dev parrot",
            ))
          False -> Nil
        }
        use config <- result.try(config.resolve(flags, toml, envoy.get))
        use _ <- result.map(generate(config, root))
        "\u{1F99C} SQL successfully generated!"
      }
    }
  }

  case result {
    Ok(text) -> {
      io.println(text)
      exit(0)
    }
    Error(e) -> {
      io.println_error(cli.red("\nError: " <> error.to_string(e)))
      exit(1)
    }
  }
}

@external(erlang, "erlang", "halt")
fn exit(status: Int) -> Nil

fn generate(
  config: config.Config,
  root: String,
) -> Result(Nil, error.ParrotError) {
  let work_dir = project.work_dir(root)
  let src = filepath.join(root, "src")
  use queries <- result.try(project.sql_files(src))
  use <- bool.guard(
    when: queries == [],
    return: Error(error.NoQueriesFound(src)),
  )

  use binary <- result.try(sqlc_binary(config.sqlc, root, work_dir))

  use schema <- result.try(case config.schema {
    config.FromFiles(path) -> Ok(sqlc.SchemaFiles(from_root(path, root)))
    config.FromDatabase(url) -> {
      io.println("\u{1F5C4} fetching schema...")
      database.fetch_schema(config.engine, url, in: root)
      |> result.map(sqlc.SchemaSql)
    }
  })

  io.println("\u{2728} generating gleam code...")
  use output <- result.try(sqlc.generate(
    binary,
    in: work_dir,
    engine: config.engine,
    schema:,
    queries:,
  ))
  use unknown_types <- result.try(codegen.generate(
    output,
    to: from_root(config.output, root),
  ))

  list.each(unknown_types, fn(unknown) {
    io.println_error(cli.yellow("unknown column type: " <> unknown))
  })
  io.println("")
  Ok(Nil)
}

fn sqlc_binary(
  sqlc: config.Sqlc,
  root: String,
  work_dir: String,
) -> Result(String, error.ParrotError) {
  case sqlc {
    config.Managed -> sqlc.managed_binary(in: work_dir)
    config.System ->
      child_process.find_executable("sqlc")
      |> result.replace_error(error.SqlcNotInPath)
      |> result.try(check_version)
    config.Binary(path) -> check_version(from_root(path, root))
  }
}

/// A binary parrot does not manage can be any version, which may or may not
/// work.
///
fn check_version(binary: String) -> Result(String, error.ParrotError) {
  use found <- result.map(sqlc.version(binary))
  let expected = "v" <> sqlc.sqlc_version
  case found == expected {
    True -> Nil
    False ->
      io.println_error(cli.yellow(
        "warning: expected sqlc " <> expected <> ", found " <> found,
      ))
  }
  binary
}

/// Paths in the config are relative to the project's root.
///
fn from_root(path: String, root: String) -> String {
  case filepath.is_absolute(path) {
    True -> path
    False -> filepath.join(root, path)
  }
}
