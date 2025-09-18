# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
