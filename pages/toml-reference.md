# TOML reference

Parrot follow Gleam's tools convention and can be configured in your project's `gleam.toml` file under the `tools.parrot` table.

```toml
[tools.parrot.bin]
# Use the system-installed `sqlc` binary instead of downloading one automatically.
sqlc = "system"
# Override the sqlc version that is downloaded automatically (default: latest)
sqlc_version = "v1.30.0"
```

> **Note**: that any flags passed to the command line will always take precedence
> over any configuration in your `gleam.toml`

## `tools.parrot.bin`

These options allow you to configure what binaries Parrot uses as part of the build and development process.

- **`sqlc = "system" | string`**: choose a local sqlc binary to use instead of letting
  Parrot download and manage its own sqlc version. You can specify a path to the
  sqlc binary you want to use, or the string `"system"` to look up the `sqlc`
  executable in your system `PATH`.

  Default: `undefined`. Parrot will download and manage its own sqlc version.

- **`sqlc_version = "latest" | string`**: choose the version of sqlc that Parrot will download
  and manage, when no sqlc binary is specified.

  Versions are specified like this: `v1.30.0`. A list of all available sqlc versions can be found
  here: https://github.com/sqlc-dev/sqlc/releases/.

  Default: `undefined`. Parrot will download the latest sqlc version.
