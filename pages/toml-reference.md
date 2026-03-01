# TOML reference

Parrot follow Gleam's tools convention and can be configured in your project's `gleam.toml` file under the `tools.parrot` table.

```toml
[tools.parrot]
output = "./src/app/custom_module.gleam"

[tools.parrot.sqlc]
# Use the system-installed `sqlc` binary instead of downloading one automatically.
bin = "system"
# Override the sqlc version that is downloaded automatically (default: latest)
version = "v1.30.0"
# Provide a path to a schema or migration files
schema = "<path>"
```

> **Note**: that any flags passed to the command line will always take precedence
> over any configuration in your `gleam.toml`

## `tools.parrot`

- **`output = string`**: 

  Default: `.src/<project_name>/sql.gleam`.

## `tools.parrot.sqlc`

These options allow you to configure sqlc and how Parrot uses as part of the build and development process.

- **`bin = "system" | string`**: choose a local sqlc binary to use instead of letting
  Parrot download and manage its own sqlc version. You can specify a path to the
  sqlc binary you want to use, or the string `"system"` to look up the `sqlc`
  executable in your system `PATH`.

  Default: `undefined`. Parrot will download and manage its own sqlc version.

- **`version = string`**: choose the version of sqlc that Parrot will download
  and manage, when no sqlc binary is specified.

  Versions are specified like this: `v1.30.0`. A list of all available sqlc versions can be found
  here: <https://github.com/sqlc-dev/sqlc/releases/>.

  Default: `undefined`. Parrot will download the latest sqlc version.

- **`schema = string`**: sqlc can parse various migration files to build up the schema even without a database connection.

  You can read more about it here: <https://docs.sqlc.dev/en/stable/howto/ddl.html#handling-sql-migrations>
  
  Default: `undefined`. Parrot will attempt to fetch the schema from the database connection string.
