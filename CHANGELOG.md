# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

**Version 3**

### Breaking Changes

- Configuration in `gleam.toml` under `[tools.parrot]`: `output`, `env`, `engine`, `sqlc.bin`, `sqlc.schema`. See `pages/toml-reference.md`.
  - `--output`, `--engine`, `--schema` and `--sqlc` flags, which take precedence over `gleam.toml`.
  - `schema` generates code from schema or migration files without a database connection. (https://github.com/daniellionel01/parrot/issues/66)
  - `sqlc.bin` uses your own sqlc binary instead of downloading one. (https://github.com/daniellionel01/parrot/issues/96)

- Unknown command line arguments are an error instead of printing the help text.

- Parrot can now be a dev dependency! All code, that was previously required from `parrot/dev` is now bundled into the output module.

- Postgres `time` columns are now decoded as `calendar.TimeOfDay` instead of `timestamp.Timestamp`. There is a new `ParamTimeOfDay` parameter variant.

- Postgres `interval`, `inet`, `cidr` and `macaddr` columns are now `Interval`, `Inet` and `BitArray`, with new `ParamInterval`, `ParamInet` and `ParamMacaddr` variants. `interval` was wrongly decoded as `Int`.

- Postgres `timetz` columns are now `decode.Dynamic`. Previously they were wrongly decoded as `Timestamp`.

### Fixes

- Postgres enum arrays (f.e. `mood[]`) generated code that did not compile.

- "unknown column type" warnings now also include nullable and array columns.

- Queries using `sqlc.embed` return an error. Previously parrot generated decoders that silently read the wrong columns.

- `calendar_date_decoder` and `time_of_day_decoder` also decode `YYYY-MM-DD` and `HH:MM:SS` strings (sqlite) and `{0, {h, m, s}}` (mysql).

- Postgres `char` columns (`bpchar`) are now decoded as `String` instead of `decode.Dynamic`.

- `sqlc.slice` queries generated invalid sql with a leading comma (`in (,?,?)`). Empty lists are now replaced with `NULL`, same as sqlc does for go.

- Unnamed parameters, unsupported query annotations (`:execrows`, `:execlastid`, ...) and a sqlc binary checksum mismatch now return an error instead of crashing parrot.

- Fixed a crash on the very first run, when no sqlc binary had been downloaded yet.

- Parrot now always uses the sqlc binary it manages itself, instead of whichever `sqlc` is first in the `PATH`.

- Parrot no longer crashes on any error, it always exits with a descriptive error message.

- Parrot no longer loops forever when it is run outside of a gleam project.

- Running parrot from a subdirectory of the project no longer fails to find the queries.

- `file:` sqlite connection strings work. Previously they were detected as sqlite but the database was "not found".

- MySQL passwords are passed via `MYSQL_PWD`: passwords may contain `:`, connection strings without a password no longer prompt for one, and schema lines containing `mysqldump:` are no longer dropped.

- Queries named like a gleam keyword (f.e. `Use`) generated a function that did not compile.

- The managed sqlc binary is downloaded again if it does not match its checksum, instead of returning an error.

- Datetimes without an offset, as sqlite's own date and time functions write them (f.e. `CURRENT_TIMESTAMP`), are decoded as UTC instead of failing.

- MySQL user names and passwords in the connection string are percent-decoded, so f.e. `p%40ss` is the password `p@ss`.

- Relative sqlite paths (`--sqlite` and connection strings) are relative to the project's root, like every other path, instead of the current directory.

- Warnings of `pg_dump`, `mysqldump` and `sqlite3` are printed instead of ending up in the fetched schema.

- A parameter named `sql` was silently sent as the query's sql text instead of its value.

- Duplicate parameter and column names (f.e. `where id = ? or id = ?` or `select count(*), count(*)`) get a suffix like sqlc does for go (`id`, `id_2`). Parameters and columns named like a generated function (f.e. `bool_decoder`) or variable (f.e. `<slice>_slice`) no longer shadow it.

- Names that would be defined twice in the generated module return an error instead of generating code that does not compile, f.e. an enum value `open` and a query `Open`, an enum value `date` and the imported `Date`, or the queries `GetUser` and `get_user`.

- `:exec` and `:execresult` queries with a `returning` clause no longer generate an unused row type and decoder.

- Generated functions have return type annotations.

## [2.3.0] - 2026-05-04

- Add support for windows arm64 platform, since sqlc released a binary for it. (https://github.com/daniellionel01/parrot/pull/99)

- Upgrade to sqlc v1.31.1. (https://github.com/daniellionel01/parrot/pull/99)

- All queries are ordered with `string.compare` to produce deterministic outputs regardless of operating system. (https://github.com/daniellionel01/parrot/pull/102)

## [2.2.2] - 2026-01-31

- Only import `Option` when used somewhere in the generated code. (https://github.com/daniellionel01/parrot/pull/95)

## [2.2.1] - 2026-01-30

- Adds support for `citext` type in Postgres (https://github.com/daniellionel01/parrot/pull/92)<br />
  Thank you uh-kay! (https://github.com/uh-kay)

## [2.2.0] - 2026-01-27

- Adds support for `sqlc.slice` syntax. (https://github.com/daniellionel01/parrot/pull/91)<br />
  This enables dynamic parameters for `in` queries in SQlite und MySQL who do not support it natively.

## [2.1.3] - 2026-01-18

- Improvement: dedicated error message for duplicate enum definitions. (https://github.com/daniellionel01/parrot/issues/82)
- Improvement: dedicated error message for empty enum values. (https://github.com/daniellionel01/parrot/issues/84)

## [2.1.2] - 2025-10-16

- Parrot now generates a `sqlc.json` instead of a yaml configuration. (https://github.com/daniellionel01/parrot/pull/71)<br />
  Thank you szelbi! (https://github.com/sz3lbi)

- Remove `given` dependency (sorry inoas <3). (https://github.com/daniellionel01/parrot/pull/72)<br />
  Thank you szelbi! (https://github.com/sz3lbi)

- Remove `gleam_regexp` dependency.

- Support column names that collide with keywords built into Gleam. (https://github.com/daniellionel01/parrot/issues/74)

## [2.1.1] - 2025-09-30

- Bug Fix: quotes are escaped properly in generated gleam code. (https://github.com/daniellionel01/parrot/pull/65)

## [2.1.0] - 2025-09-28

- Improve surfacing of errors from `pg_dump`. (https://github.com/daniellionel01/parrot/pull/57/)<br />
  Thank you Ross! (https://github.com/ross-byrne/)

- Remove fallback to system wide sqlc binary (introduced in `v1.2.0`).

- Add support for `Date` values. (https://github.com/daniellionel01/parrot/pull/60)<br />
  Thank you Ross! (https://github.com/ross-byrne/)

- Updated the `given` dependency to >= 6.0.0 and < 7.0.0. (https://github.com/daniellionel01/parrot/pull/61)<br />
  Thank you inoas! (https://github.com/inoas)

## [2.0.1] - 2025-09-21

- Support queries where no column name is available (f.e. `select 1`) (https://github.com/daniellionel01/parrot/pull/54)

## [2.0.0] - 2025-09-20

- **Bug Fix and Breaking Change:** nullable / optional columns did not get wrapped properly in an `Option`. (https://github.com/daniellionel01/parrot/pull/52)<br />
  This fix introduces a new `dev.ParamNullable` that has to be added to your case statement. The wrappers for `pog` and `sqlight` have been updated.

- Remove sqlight dependency in favor of local `sqlite3` binary. (https://github.com/daniellionel01/parrot/pull/49)<br />
  Thank you Ross! (https://github.com/ross-byrne/)

## [1.2.12] - 2025-09-18

- Bug Fix: `sqlite:` was not used consistently during codegen.

## [1.2.11] - 2025-09-18

- Improvement: support `sqlite:` prefix for `DATABASE_URL`.

## [1.2.10] - 2025-09-07

- Improvement: remove need for custom json plugin with built-in json-output from sqlc (https://github.com/daniellionel01/parrot/pull/46)<br />
  Thank you Mike! (https://github.com/mbuhot)

## [1.2.9] - 2025-09-05

- Bug fix: parameter list types generate invalid gleam code (https://github.com/daniellionel01/parrot/pull/45)<br />
  Thank you Mike! (https://github.com/mbuhot)

## [1.2.8] - 2025-09-02

- Handle case where cached sqlc version is outdated

## [1.2.7] - 2025-09-02

- Bump sqlc to v1.30.0

## [1.2.6] - 2025-07-27

- Closes https://github.com/daniellionel01/parrot/issues/21<br />
  Throw error on unsupported sqlc query annotation syntaxes.

- Closes https://github.com/daniellionel01/parrot/issues/18<br />
  Automatically check for new sqlc versions every 24h.

## [1.2.5] - 2025-07-25

- Closes https://github.com/daniellionel01/parrot/issues/29<br />
  Upgrades dependencies across project & integration tests.

## [1.2.4] - 2025-07-16

- Closes https://github.com/daniellionel01/parrot/issues/6<br />
  Infer `tinyint(1)` to `Bool`

## [1.2.3] - 2025-07-16

- Closes https://github.com/daniellionel01/parrot/issues/23<br />
  We now check the hash integrity of the downloaded sqlc binary. Thank you [@hayleigh-dot-dev](https://github.com/hayleigh-dot-dev) for calling me out.

## [1.2.2] - 2025-07-16

- Closes https://github.com/daniellionel01/parrot/issues/30<br />
  The generated `sql.gleam` file is now formatted with the gleam formatter.

## [1.2.1] - 2025-07-08

- Bug Fix https://github.com/daniellionel01/parrot/issues/27<br />
  This is an edge case when you cast a type for a non-named argument, which lead to
  an empty string for the gleam function parameter.

## [1.2.0] - 2025-07-01

- Only issue a warning when download of sqlc binary was not successfull. This makes parrot
  work without an internet connection if sqlc is already downloaded or installed system wide.
- Use system wide sqlc binary as fallback, if local sqlc binary throws an error. This
  is an edge case on MacOS.

## [1.1.2] - 2025-06-26

- Bug Fix: `sqlc generate` fails due to incorrect path resolution on Linux

## [1.1.1] - 2025-06-26

- Output debugging information, when sqlc binary download fails

## [1.1.0] - 2025-06-25

- Support `List` columns in Postgres.<br />
  **Requires handling `dev.ParamList` in wrapper**
- Decodes `JSON`, `JSONB`, `MONEY`
  (not `Dynamic` anymore)
- Support for Postgres & MySQL `ENUM`
  (creates a custom type)
- Improved testing for all databases
  (more data types & operations)
- Use of `assert` syntax
  (instead of `gleeunit/should`)

## [1.0.1] - 2025-06-19

- Provide empty list instead of `Nil` when there are no parameters for a consistent return type

## [1.0.0] - 2025-06-19

- 🦜 Initial Release!
